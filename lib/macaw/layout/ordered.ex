defmodule Macaw.Layout.Ordered do
  @moduledoc false
  # What the layouts that order their cells by a list share (spec/06 §3.3): `:stack` and
  # `:flow`. Their one option, `order`, is every cell's name once, in reading order; a cell
  # has no place, and its declared size is the surface's width and four rows.

  alias Macaw.Layers.{Fault, Names}

  @rows 4

  @doc false
  # `order`, required: a list of names, each read as its spelling. Which cells it names is
  # checked against the cells (`faults/2`).
  @spec options(keyword() | map()) :: {:ok, %{order: [String.t()]}} | {:error, [Fault.t(), ...]}
  def options(given) do
    given = Map.new(given)

    unknown =
      for key <- Map.keys(given), key != :order, do: {[:layout, :options, key], :unknown_key}

    {order, o} =
      case Map.fetch(given, :order) do
        :error -> {[], [{[:layout, :options, :order], :required}]}
        {:ok, list} when is_list(list) -> names(list)
        {:ok, _other} -> {[], [{[:layout, :options, :order], {:type, {:list, :name}}}]}
      end

    case unknown ++ o do
      [] -> {:ok, %{order: order}}
      faults -> {:error, Fault.sort(faults)}
    end
  end

  defp names(list) do
    spelled = Enum.map(list, &Names.name/1)

    case for {name, i} <- Enum.with_index(spelled), not is_binary(name), do: i do
      [] -> {spelled, []}
      bad -> {[], for(i <- bad, do: {[:layout, :options, :order, i], {:type, :name}})}
    end
  end

  @doc false
  # A cell under an ordered layout has no place: one given is `{:not_taken, layout}`.
  @spec place(term(), String.t()) :: {:ok, nil} | {:error, [Fault.t(), ...]}
  def place(nil, _layout), do: {:ok, nil}
  def place(_given, layout), do: {:error, [{[], {:not_taken, layout}}]}

  @doc false
  # The order names every cell exactly once: a name no cell has is `{:unknown_cell, name}`
  # and a name given again `{:duplicate, name}`, each at its index; a cell it leaves out is
  # `{:missing, name}` at the order.
  @spec faults(map(), %{order: [String.t()]}) :: [Fault.t()]
  def faults(cells, %{order: order}) do
    at = [:layout, :options, :order]

    {listed, _seen} =
      order
      |> Enum.with_index()
      |> Enum.reduce({[], MapSet.new()}, fn {name, i}, {faults, seen} ->
        cond do
          not Map.has_key?(cells, name) -> {[{at ++ [i], {:unknown_cell, name}} | faults], seen}
          MapSet.member?(seen, name) -> {[{at ++ [i], {:duplicate, name}} | faults], seen}
          true -> {faults, MapSet.put(seen, name)}
        end
      end)

    missing =
      for name <- cells |> Map.keys() |> Enum.sort(),
          name not in order,
          do: {at, {:missing, name}}

    Fault.sort(listed ++ missing)
  end

  @doc false
  # The cells in the order, each once.
  @spec order(map(), %{order: [String.t()]}) :: [String.t()]
  def order(cells, %{order: order}),
    do: order |> Enum.uniq() |> Enum.filter(&Map.has_key?(cells, &1))

  @doc false
  # The surface's width, and four rows.
  @spec size(number(), number()) :: {number(), number()}
  def size(width, row_height) when width > 0 and row_height > 0, do: {width, @rows * row_height}
end
