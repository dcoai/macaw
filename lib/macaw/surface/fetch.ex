defmodule Macaw.Surface.Fetch do
  @moduledoc false
  # Fetching a validated surface's slots (spec/06 §3.5): budgets at each cell's declared
  # size clamped to the host ceiling, pooled within the surface by source and params, each
  # fetch bounded in a process of its own, finished, reduced to each reader, and drawn.

  alias Macaw.Component
  alias Macaw.Component.Drawn
  alias Macaw.Data.{Bounded, Delivery, Source}
  alias Macaw.Data.Source.{Finish, Request}
  alias Macaw.Surface.{Env, Sources, Validated}

  @defaults [viewer: nil, width: 1200, row_height: 64, timeout: 5_000]

  @doc false
  @spec fetch(Validated.t(), keyword()) :: %{String.t() => %{deliveries: map(), drawn: Drawn.t()}}
  def fetch(%Validated{} = validated, env) when is_list(env) do
    env = Keyword.merge(@defaults, env)
    now = Keyword.fetch!(env, :now)
    ceiling = Keyword.fetch!(env, :ceiling)

    case Env.fetch_faults(env) do
      [] -> slots(validated, env, now, ceiling)
      _faults -> refused(validated)
    end
  end

  # An env whose values can't fetch: every slot's cell is invalid, with nothing fetched.
  defp refused(validated) do
    Map.new(validated.order, fn name ->
      slots = Map.fetch!(validated.cells, name).slots
      {name, %{deliveries: %{}, drawn: Drawn.pick(Enum.map(slots, fn _slot -> :invalid end))}}
    end)
  end

  defp slots(validated, env, now, ceiling) do
    sources = Keyword.get(env, :sources)
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
  # component asks for (`Component.resolve_order/4`, its role keys resolved through the
  # slot's binding, then checked against the slot's schema) and budget
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

      order = order(cell, slot, binding)

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

  # The order a slot's component asks for, in fields, when the slot's schema can answer it.
  defp order(cell, slot, binding) do
    with {:ok, order} <- Component.resolve_order(cell.module, slot, cell.settings, binding.fields),
         [] <- Macaw.Data.Source.Order.faults(order, binding.description.schema) do
      order
    else
      _bad -> :invalid
    end
  end

  # Slots of one source pool when they ask for the same params and the same order: a
  # delivery's first rows are first in one order only.
  defp fetch_group(sources, {source, params, order}, group, env, now) do
    budget = Finish.pooled(Enum.map(group, & &1.budget))

    with {:ok, struct, _context} <- Sources.entry(sources, source),
         {:ok, request} <-
           Request.new(
             params: params,
             order: order,
             budget: budget,
             viewer: env[:viewer],
             now: now
           ) do
      fetched(struct, hd(group).description, request, env)
    else
      # A source gone or malformed since validation, or a request the slots' params, order
      # and budget can't make: their cells are invalid.
      _unfetchable -> {:drawn, :invalid}
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

  # Every fact of a delivery goes through the one precedence (macaw_component 02 §6), so an
  # empty answer is no data whatever else it says, and a stale one says so even when capped.
  defp drawn(%Delivery{served: served} = delivery) do
    Drawn.pick([
      if(Delivery.empty?(delivery), do: :no_data, else: :live),
      if(served.stale, do: :stale, else: :live),
      if(served.capped or served.reduced_by != nil, do: :capped, else: :live)
    ])
  end
end
