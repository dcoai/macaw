defmodule Macaw.Surface.Fetch do
  @moduledoc false
  # Fetching a validated surface's slots (spec/06 §3.5): budgets at each cell's declared
  # size clamped to the host ceiling, pooled within the surface by source and params, each
  # fetch bounded in a process of its own, finished, reduced to each reader, and drawn.

  alias Macaw.Component
  alias Macaw.Component.Drawn
  alias Macaw.Data.{Bounded, Delivery, Source, Table}
  alias Macaw.Data.Source.{Finish, Request}
  alias Macaw.Grid
  alias Macaw.Surface.Validated

  @defaults [viewer: nil, width: 1200, row_height: 64, timeout: 5_000]

  @doc false
  @spec fetch(Validated.t(), keyword()) :: %{String.t() => %{deliveries: map(), drawn: Drawn.t()}}
  def fetch(%Validated{} = validated, env) when is_list(env) do
    env = Keyword.merge(@defaults, env)
    sources = Keyword.fetch!(env, :sources)
    now = Keyword.fetch!(env, :now)
    ceiling = Keyword.fetch!(env, :ceiling)

    readers = readers(validated, env, ceiling)

    outcomes =
      readers
      |> Enum.reject(&match?(%{budget: :invalid}, &1))
      |> Enum.group_by(&{&1.source, &1.params})
      |> Task.async_stream(
        fn {{source, params}, group} ->
          {{source, params}, fetch_group(sources, source, params, group, env, now)}
        end,
        timeout: :infinity,
        ordered: true
      )
      |> Map.new(fn {:ok, pair} -> pair end)

    Map.new(validated.order, fn cell ->
      mine = Enum.filter(readers, &(&1.cell == cell))

      {deliveries, states} =
        Enum.reduce(mine, {%{}, []}, fn reader, {deliveries, states} ->
          case slot_outcome(reader, outcomes) do
            {:ok, delivery} ->
              {Map.put(deliveries, reader.slot, delivery), [drawn(delivery) | states]}

            {:drawn, state} ->
              {deliveries, [state | states]}
          end
        end)

      {cell, %{deliveries: deliveries, drawn: Drawn.pick(states)}}
    end)
  end

  # One reader per bound slot: its cell, slot, source, params, description and budget at
  # its cell's declared size, clamped to the ceiling. A bad budget is the cell's `invalid`.
  defp readers(validated, env, ceiling) do
    for name <- validated.order,
        cell = Map.fetch!(validated.cells, name),
        place = Map.fetch!(validated.surface.cells, name).place,
        {slot, binding} <- Enum.sort(cell.slots) do
      size = Grid.size(place, env[:width], env[:row_height])

      {budget, clamped} =
        case Component.budget(cell.module, slot, cell.settings, size) do
          {:ok, rows} -> Finish.ceiling(rows, host: ceiling)
          {:error, _bad} -> {:invalid, false}
        end

      %{
        cell: name,
        slot: slot,
        source: binding.source,
        params: binding.params,
        description: binding.description,
        budget: budget,
        clamped: clamped
      }
    end
  end

  defp fetch_group(sources, source, params, group, env, now) do
    {struct, _context} = Map.fetch!(sources, source)
    description = hd(group).description
    budget = Finish.pooled(Enum.map(group, & &1.budget))
    {:ok, request} = Request.new(params: params, budget: budget, viewer: env[:viewer], now: now)

    case Bounded.run(fn -> Source.fetch(struct, description, request) end, timeout: env[:timeout]) do
      {:ok, {:ok, %Delivery{} = delivery}, _spent} ->
        {:ok, Finish.finish(delivery, description, request)}

      {:ok, _error, _spent} ->
        {:drawn, :down}

      {:down, _reason} ->
        {:drawn, :down}

      :hung ->
        {:drawn, :loading}
    end
  end

  defp slot_outcome(%{budget: :invalid}, _outcomes), do: {:drawn, :invalid}

  defp slot_outcome(reader, outcomes) do
    case Map.fetch!(outcomes, {reader.source, reader.params}) do
      {:ok, delivery} ->
        reduced = Finish.reduce(delivery, reader.description.schema, reader.budget)
        {:ok, if(reader.clamped, do: runtime(reduced), else: reduced)}

      drawn ->
        drawn
    end
  end

  # A clamped slot's delivery says the runtime brought it within budget.
  defp runtime(%Delivery{served: served} = delivery),
    do: %{delivery | served: %{served | reduced_by: :runtime}}

  defp drawn(%Delivery{served: served, table: table}) do
    cond do
      served.capped or served.reduced_by != nil -> :capped
      Table.size(table) == 0 -> :no_data
      true -> :live
    end
  end
end
