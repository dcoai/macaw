defmodule Macaw.Surface.Fetch do
  @moduledoc false
  # Fetching a validated surface's slots (spec/06 §3.5): budgets at each cell's declared
  # size clamped to the host ceiling, pooled within the surface by source and params, each
  # fetch bounded in a process of its own, finished, reduced to each reader, and drawn.

  alias Macaw.Component
  alias Macaw.Component.Drawn
  alias Macaw.Data.{Bounded, Delivery, Source}
  alias Macaw.Data.Source.{Finish, Request}
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
      |> Enum.group_by(&{&1.source, &1.params, &1.order})
      |> Task.async_stream(
        fn {key, group} -> {key, fetch_group(sources, key, group, env, now)} end,
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

  # One reader per bound slot: its cell, slot, source, params, description, the order its
  # component asks for (`Component.order/3`, checked against the slot's schema) and budget
  # at its cell's declared size, clamped to the ceiling. A bad budget, or an order of no
  # shape or naming a field the schema lacks, is the cell's `invalid`.
  defp readers(validated, env, ceiling) do
    # The place is read in the body: a comprehension's `place = …` is a filter, which drops
    # a cell whose place is `nil`, a stack's or a flow's (#232).
    for name <- validated.order,
        cell = Map.fetch!(validated.cells, name),
        {slot, binding} <- Enum.sort(cell.slots) do
      place = Map.fetch!(validated.surface.cells, name).place
      {layout, options} = validated.layout
      size = layout.size(place, options, env[:width], env[:row_height])

      {budget, clamped} =
        with {:ok, rows} <- Component.budget(cell.module, slot, cell.settings, size),
             {:ok, clamped} <- Finish.ceiling(rows, host: ceiling) do
          clamped
        else
          {:error, _bad} -> {:invalid, false}
        end

      order = order(cell, slot, binding.description.schema)

      %{
        cell: name,
        slot: slot,
        source: binding.source,
        params: binding.params,
        description: binding.description,
        order: order,
        budget: if(order == :invalid, do: :invalid, else: budget),
        clamped: clamped
      }
    end
  end

  # The order a slot's component asks for, when the slot's schema can answer it.
  defp order(cell, slot, schema) do
    with {:ok, order} <- Component.order(cell.module, slot, cell.settings),
         [] <- Macaw.Data.Source.Order.faults(order, schema) do
      order
    else
      _bad -> :invalid
    end
  end

  # Slots of one source pool when they ask for the same params and the same order: a
  # delivery's first rows are first in one order only.
  defp fetch_group(sources, {source, params, order}, group, env, now) do
    {struct, _context} = Map.fetch!(sources, source)
    description = hd(group).description
    budget = Finish.pooled(Enum.map(group, & &1.budget))

    case Request.new(params: params, order: order, budget: budget, viewer: env[:viewer], now: now) do
      {:ok, request} -> fetched(struct, description, request, env)
      # A request the slots' params, order and budget can't make: their cells are invalid.
      {:error, _faults} -> {:drawn, :invalid}
    end
  end

  # A fetch's outcome: the delivery finished against the description, or the drawn state
  # of a source that failed, crashed or hung. A delivery finishing refuses is `invalid`.
  defp fetched(struct, description, request, env) do
    case Bounded.run(fn -> Source.fetch(struct, description, request) end, timeout: env[:timeout]) do
      {:ok, {:ok, %Delivery{} = delivery}, _spent} ->
        case Finish.finish(delivery, description, request) do
          {:ok, finished} -> {:ok, finished}
          {:error, _faults} -> {:drawn, :invalid}
        end

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
    case Map.fetch!(outcomes, {reader.source, reader.params, reader.order}) do
      {:ok, delivery} ->
        case Finish.reduce(delivery, reader.description.schema, reader.budget) do
          {:ok, reduced} -> {:ok, if(reader.clamped, do: runtime(reduced), else: reduced)}
          {:error, _faults} -> {:drawn, :invalid}
        end

      drawn ->
        drawn
    end
  end

  # A clamped slot's delivery says the runtime brought it within budget.
  defp runtime(%Delivery{served: served} = delivery),
    do: %{delivery | served: %{served | reduced_by: :runtime}}

  defp drawn(%Delivery{served: served} = delivery) do
    cond do
      served.capped or served.reduced_by != nil -> :capped
      Delivery.empty?(delivery) -> :no_data
      true -> :live
    end
  end
end
