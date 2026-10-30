defmodule Macaw.Surface.Validated do
  @moduledoc """
  A surface that passed the static pass (spec/06 §3.4), and what rendering needs of it:
  each cell's component module, validated settings and declarations, and each slot's
  source, description, resolved binding (`Slot.resolve/3`) and request params; `order` is the cells in reading order.

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

  # Each check runs on what it needs (spec/06 §3.4), so one failure never hides another:
  # a binding's source and params need only the cell; the kind and settings the component;
  # which slots exist and each binding's fields the configured declarations. Checks a failed
  # prerequisite rules out are reported as {:unchecked, prerequisite}, never skipped silently.
  defp cell(name, cell, registry, sources, described) do
    path = [:cells, name]
    {bindings, binding_faults} = bindings(path, cell, sources, described)

    {configured, faults} =
      case Registry.component(registry, cell.component) do
        {:ok, module} -> configured(path, module, cell)
        :error -> {:unchecked, [{path ++ [:component], {:unknown_component, cell.component}}]}
      end

    {built, slot_faults} = slots(path, cell, configured, bindings)

    case binding_faults ++ faults ++ slot_faults do
      [] -> {:ok, built}
      all -> {:error, all}
    end
  end

  # The kind, settings and declarations of a known component.
  defp configured(path, module, cell) do
    {:ok, info} = Component.info(module)

    kind =
      if cell.kind in info.kinds,
        do: [],
        else: [{path ++ [:kind], {:kind_not_offered, cell.kind, info.kinds}}]

    case {Component.declarations(module, cell.settings),
          Component.settings(module, cell.settings)} do
      {{:ok, declarations}, {:ok, settings}} ->
        {{module, settings, declarations}, kind}

      {{:error, faults}, _settings} ->
        {:unchecked_settings, kind ++ for({p, r} <- faults, do: {path ++ [:settings | p], r})}
    end
  end

  # Each binding's source and params, which need no component.
  defp bindings(path, cell, sources, described) do
    Enum.reduce(cell.slots, {%{}, []}, fn {slot, binding}, {acc, faults} ->
      case binding(path ++ [:slots, slot], binding, sources, described) do
        {:ok, built, []} -> {Map.put(acc, slot, built), faults}
        {:ok, built, more} -> {Map.put(acc, slot, built), faults ++ more}
        {:error, more} -> {acc, faults ++ more}
      end
    end)
  end

  defp slots(path, cell, {module, settings, declarations}, bindings) do
    declared = declarations.slots

    unbound =
      for slot <- Map.keys(declared),
          not Map.has_key?(cell.slots, slot),
          do: {path ++ [:slots, slot], :unbound}

    unknown =
      for slot <- Map.keys(cell.slots),
          not Map.has_key?(declared, slot),
          do: {path ++ [:slots, slot], :unknown_slot}

    fields =
      for {slot, %{description: description, fields: given}} <- bindings,
          Map.has_key?(declared, slot),
          {p, r} <- fields(declared[slot], description, given),
          do: {path ++ [:slots, slot, :fields | p], r}

    case unbound ++ unknown ++ fields do
      [] ->
        # Each binding resolved (`Slot.resolve/3`): the field each role reads, an unbound
        # window role's window field included. The cell's context carries it (§3.6).
        slots =
          Map.new(bindings, fn {slot, built} ->
            resolved = Slot.resolve(declared[slot], built.description.schema, built.fields)
            {slot, %{built | fields: resolved}}
          end)

        {%{module: module, settings: settings, declarations: declarations, slots: slots}, []}

      faults ->
        {nil, faults}
    end
  end

  defp slots(_path, cell, unchecked, _bindings) when cell.slots == %{} and is_atom(unchecked),
    do: {nil, []}

  defp slots(path, _cell, :unchecked, _bindings),
    do: {nil, [{path ++ [:slots], {:unchecked, :component}}]}

  defp slots(path, _cell, :unchecked_settings, _bindings),
    do: {nil, [{path ++ [:slots], {:unchecked, :settings}}]}

  defp fields(declared, description, given) do
    case Slot.check(declared, description.schema, given) do
      :ok -> []
      {:error, faults} -> faults
    end
  end

  # A binding's source, described, and its params against the description. A described
  # binding is kept even when its params fail, so its fields are still checked.
  defp binding(path, binding, sources, described) do
    with {:source, true} <- {:source, Map.has_key?(sources, binding.source)},
         {:describe, {:ok, %Description{} = description}} <-
           {:describe, Map.fetch!(described, binding.source)} do
      {params, faults} =
        case Parameter.validate(description.params, binding.params) do
          {:ok, params} -> {params, []}
          {:error, faults} -> {%{}, for({p, r} <- faults, do: {path ++ [:params | p], r})}
        end

      {:ok,
       %{
         source: binding.source,
         description: description,
         fields: binding.fields,
         params: params
       }, faults}
    else
      {:source, false} -> {:error, [{path ++ [:source], {:unknown_source, binding.source}}]}
      {:describe, {:error, reason}} -> {:error, [{path ++ [:source], {:describe, reason}}]}
    end
  end
end
