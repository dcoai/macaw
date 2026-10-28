defmodule Macaw.Surface.Validated do
  @moduledoc """
  A surface that passed the static pass (spec/06 §3.4), and what rendering needs of it:
  each cell's component module, validated settings and declarations, and each slot's
  source, description, fields and request params; `order` is the cells in reading order.

  Rendering takes only a validated surface, so nothing renders that hasn't passed.
  """

  alias Macaw.Component
  alias Macaw.Data.Parameter
  alias Macaw.Data.Source
  alias Macaw.Data.Source.Description
  alias Macaw.Layers.Fault
  alias Macaw.{Grid, Registry, Surface}
  alias Macaw.Component.Slot

  @enforce_keys [:surface, :cells, :order]
  defstruct [:surface, :cells, :order]

  @type slot :: %{
          source: String.t(),
          description: Description.t(),
          fields: map(),
          params: map()
        }

  @type cell :: %{
          module: module(),
          settings: map(),
          declarations: Component.Declarations.t(),
          slots: %{String.t() => slot()}
        }

  @type t :: %__MODULE__{
          surface: Surface.t(),
          cells: %{String.t() => cell()},
          order: [String.t()]
        }

  @doc false
  # The static pass: every fault at once, by path from the surface.
  @spec validate(Surface.t(), Registry.t(), %{String.t() => {Source.t(), term()}}) ::
          {:ok, t()} | {:error, [Fault.t(), ...]}
  def validate(%Surface{} = surface, %Registry{} = registry, sources) when is_map(sources) do
    described = describe(surface, sources)

    {cells, faults} =
      Enum.reduce(surface.cells, {%{}, []}, fn {name, cell}, {acc, faults} ->
        case cell(name, cell, registry, sources, described) do
          {:ok, built} -> {Map.put(acc, name, built), faults}
          {:error, more} -> {acc, faults ++ more}
        end
      end)

    case Fault.sort(Grid.faults(surface.cells) ++ faults) do
      [] -> {:ok, %__MODULE__{surface: surface, cells: cells, order: Grid.order(surface.cells)}}
      all -> {:error, all}
    end
  end

  # Each source a cell binds, described once, without a viewer.
  defp describe(surface, sources) do
    names =
      for {_name, cell} <- surface.cells,
          {_slot, %{source: source}} <- cell.slots,
          uniq: true,
          do: source

    for source <- names,
        {:ok, {s, context}} <- [Map.fetch(sources, source)],
        into: %{},
        do: {source, Source.describe(s, context)}
  end

  defp cell(name, cell, registry, sources, described) do
    path = [:cells, name]

    with {:component, {:ok, module}} <- {:component, Registry.component(registry, cell.component)},
         {:ok, info} <- Component.info(module),
         {:kind, true} <- {:kind, cell.kind in info.kinds},
         {:declarations, {:ok, declarations}} <-
           {:declarations, Component.declarations(module, cell.settings)},
         {:ok, settings} <- Component.settings(module, cell.settings),
         {:slots, {slots, []}} <- {:slots, slots(path, cell, declarations, sources, described)} do
      {:ok, %{module: module, settings: settings, declarations: declarations, slots: slots}}
    else
      {:component, :error} ->
        {:error, [{path ++ [:component], {:unknown_component, cell.component}}]}

      {:kind, false} ->
        {:error, [{path ++ [:kind], {:kind_not_offered, cell.kind, kinds(registry, cell)}}]}

      {:declarations, {:error, faults}} ->
        {:error, for({p, r} <- faults, do: {path ++ [:settings | p], r})}

      {:slots, {_slots, faults}} ->
        {:error, faults}
    end
  end

  defp kinds(registry, cell) do
    {:ok, module} = Registry.component(registry, cell.component)
    {:ok, info} = Component.info(module)
    info.kinds
  end

  defp slots(path, cell, declarations, sources, described) do
    declared = declarations.slots

    unbound =
      for slot <- Map.keys(declared),
          not Map.has_key?(cell.slots, slot),
          do: {path ++ [:slots, slot], :unbound}

    unknown =
      for slot <- Map.keys(cell.slots),
          not Map.has_key?(declared, slot),
          do: {path ++ [:slots, slot], :unknown_slot}

    {built, faults} =
      for {slot, binding} <- cell.slots, Map.has_key?(declared, slot), reduce: {%{}, []} do
        {acc, faults} ->
          case binding(
                 path ++ [:slots, slot],
                 Map.fetch!(declared, slot),
                 binding,
                 sources,
                 described
               ) do
            {:ok, built} -> {Map.put(acc, slot, built), faults}
            {:error, more} -> {acc, faults ++ more}
          end
      end

    {built, unbound ++ unknown ++ faults}
  end

  defp binding(path, declared, binding, sources, described) do
    with {:source, true} <- {:source, Map.has_key?(sources, binding.source)},
         {:describe, {:ok, %Description{} = description}} <-
           {:describe, Map.fetch!(described, binding.source)} do
      fields =
        case Slot.check(declared, description.schema, binding.fields) do
          :ok -> []
          {:error, faults} -> for {p, r} <- faults, do: {path ++ [:fields | p], r}
        end

      {params, param_faults} =
        case Parameter.validate(description.params, binding.params) do
          {:ok, params} -> {params, []}
          {:error, faults} -> {%{}, for({p, r} <- faults, do: {path ++ [:params | p], r})}
        end

      case fields ++ param_faults do
        [] ->
          {:ok,
           %{
             source: binding.source,
             description: description,
             fields: binding.fields,
             params: params
           }}

        faults ->
          {:error, faults}
      end
    else
      {:source, false} -> {:error, [{path ++ [:source], {:unknown_source, binding.source}}]}
      {:describe, {:error, reason}} -> {:error, [{path ++ [:source], {:describe, reason}}]}
    end
  end
end
