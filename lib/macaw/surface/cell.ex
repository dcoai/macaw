defmodule Macaw.Surface.Cell do
  @moduledoc """
  A cell: one component placed in a surface (spec/06 §3.2).

    * `component`, the component's name as its package registers it, matched by spelling;
    * `kind`, the kind it renders as, `:content` by default;
    * `settings`, its settings by parameter name, inline, each the term it is, checked
      against the component's parameter types where the component is known (spec/06 §3.4);
    * `slots`, each slot bound to a source: `%{source: name, fields: %{role => field},
      params: %{name => value}}`, a `many` role's fields a list, each param the term it is;
    * `place`, where it sits, as its surface's layout reads it: `%{x, y, w, h}` on the
      grid (spec/06 §3.3).

  Names are strings, normalized once here; an atom is read as its spelling, and no atom is
  made from one. A cell checks only its own shape: the types of its settings and params are
  its component's and its sources' (spec/06 §3.4).
  """

  alias Macaw.Layers.Names

  @enforce_keys [:component]
  defstruct component: nil, kind: :content, settings: %{}, slots: %{}, source: nil, place: nil

  @typedoc "Where a cell sits, as its layout reads it: `%{x, y, w, h}` on the grid."
  @type place :: term()
  @type slot :: %{
          source: String.t(),
          fields: %{String.t() => String.t() | [String.t()]},
          params: map()
        }

  @type t :: %__MODULE__{
          component: String.t(),
          kind: Macaw.Component.kind(),
          settings: %{String.t() => term()},
          slots: %{String.t() => slot()},
          source: slot() | nil,
          place: place() | nil
        }

  @keys [:component, :kind, :settings, :slots, :source, :fields, :params, :place]
  @slot_keys [:source, :fields, :params]
  @doc "A cell's keys, in order."
  @spec keys() :: [atom(), ...]
  def keys, do: @keys

  @doc """
  A cell from a keyword list or a map with atom keys: `{:ok, cell}` or every fault at
  once, by path from the cell. `layout` is the layout that judges its place
  (`Macaw.Layout`), the grid by default; `nil` holds a place as given, for a layout only
  the host's registry knows, judged when the surface is validated. A cell with no place
  is a cell; whether its surface's layout needs one is the surface's question.
  """
  @spec new(keyword() | map(), module() | nil) ::
          {:ok, t()} | {:error, [Macaw.Layers.Fault.t(), ...]}
  def new(attrs, layout \\ Macaw.Layout.default())

  def new(attrs, layout) when is_list(attrs) do
    if Keyword.keyword?(attrs),
      do: new(Map.new(attrs), layout),
      else: {:error, [{[], {:type, :map}}]}
  end

  def new(%{} = attrs, layout) when not is_struct(attrs) do
    unknown = for key <- Map.keys(attrs), key not in @keys, do: {[key], :unknown_key}

    {component, c} = component(Map.get(attrs, :component))
    {kind, k} = kind(Map.get(attrs, :kind, :content))
    {settings, s} = named(Map.get(attrs, :settings, %{}), [:settings])
    {slots, sl} = slots(Map.get(attrs, :slots, %{}))
    {source, so} = source(attrs, slots)
    {place, p} = place(Map.get(attrs, :place), layout)

    cell = %__MODULE__{
      component: component,
      kind: kind,
      settings: settings,
      slots: slots,
      source: source,
      place: place
    }

    answer(unknown ++ c ++ k ++ s ++ sl ++ so ++ p, cell)
  end

  def new(_other, _layout), do: {:error, [{[], {:type, :map}}]}

  defp component(nil), do: {nil, [{[:component], :required}]}

  defp component(name) do
    case Names.name(name) do
      spelled when is_binary(spelled) and spelled != "" -> {spelled, []}
      _ -> {nil, [{[:component], {:type, :name}}]}
    end
  end

  defp kind(kind) do
    spelled = Names.name(kind)

    case Enum.find(Macaw.Component.kinds(), &(Atom.to_string(&1) == spelled)) do
      nil -> {:content, [{[:kind], {:unknown_kind, kind}}]}
      atom -> {atom, []}
    end
  end

  defp slots(%{} = slots) when not is_struct(slots) do
    Enum.reduce(slots, {%{}, []}, fn {name, binding}, {acc, faults} ->
      name = Names.name(name)

      if is_binary(name) and name != "" do
        {slot, more} = slot(binding, [:slots, name])
        {Map.put(acc, name, slot), faults ++ more}
      else
        {acc, faults ++ [{[:slots, name], {:type, :name}}]}
      end
    end)
  end

  defp slots(_other), do: {%{}, [{[:slots], {:type, :map}}]}

  # The shorthand for a component's one slot (spec/06 §3.2): `source`, with `fields` and
  # `params` beside it, a binding with no slot name, which validation gives its slot.
  defp source(attrs, slots) do
    case {Map.fetch(attrs, :source), Map.take(attrs, [:fields, :params])} do
      {:error, beside} when beside == %{} ->
        {nil, []}

      {:error, beside} ->
        {nil, for(key <- Enum.sort(Map.keys(beside)), do: {[key], {:requires, :source}})}

      {{:ok, _source}, _beside} when slots != %{} ->
        {nil, [{[:source], :source_and_slots}]}

      {{:ok, source}, beside} ->
        {binding, faults} = slot(Map.put(beside, :source, source), [])
        {binding, faults}
    end
  end

  defp slot(%{} = binding, path) when not is_struct(binding) do
    unknown =
      for key <- Map.keys(binding), key not in @slot_keys, do: {path ++ [key], :unknown_key}

    {source, s} =
      case Names.name(Map.get(binding, :source)) do
        nil -> {nil, [{path ++ [:source], :required}]}
        name when is_binary(name) and name != "" -> {name, []}
        _ -> {nil, [{path ++ [:source], {:type, :name}}]}
      end

    {fields, f} = fields(Map.get(binding, :fields, %{}), path ++ [:fields])
    {params, p} = named(Map.get(binding, :params, %{}), path ++ [:params])
    {%{source: source, fields: fields, params: params}, unknown ++ s ++ f ++ p}
  end

  defp slot(_other, path), do: {%{source: nil, fields: %{}, params: %{}}, [{path, {:type, :map}}]}

  defp fields(%{} = fields, path) when not is_struct(fields) do
    Enum.reduce(fields, {%{}, []}, fn {role, field}, {acc, faults} ->
      role = Names.name(role)

      case field_names(field) do
        {:ok, names} when is_binary(role) and role != "" -> {Map.put(acc, role, names), faults}
        _ -> {acc, faults ++ [{path ++ [role], {:type, :name}}]}
      end
    end)
  end

  defp fields(_other, path), do: {%{}, [{path, {:type, :map}}]}

  defp field_names(list) when is_list(list) do
    names = Enum.map(list, &Names.name/1)
    if Enum.all?(names, &(is_binary(&1) and &1 != "")), do: {:ok, names}, else: :error
  end

  defp field_names(field) do
    case Names.name(field) do
      name when is_binary(name) and name != "" -> {:ok, name}
      _ -> :error
    end
  end

  defp place(nil, _layout), do: {nil, []}
  defp place(given, nil), do: {given, []}

  defp place(given, layout) do
    case layout.place(given) do
      {:ok, place} -> {place, []}
      {:error, faults} -> {nil, for({path, reason} <- faults, do: {[:place | path], reason})}
    end
  end

  # Values by name: each key a name, read as its spelling, each value the term it is.
  defp named(%{} = map, path) when not is_struct(map) do
    Enum.reduce(map, {%{}, []}, fn {k, v}, {acc, faults} ->
      case Names.name(k) do
        key when is_binary(key) and key != "" -> {Map.put(acc, key, v), faults}
        _ -> {acc, faults ++ [{path ++ [k], {:type, :name}}]}
      end
    end)
  end

  defp named(_other, path), do: {%{}, [{path, {:type, :map}}]}

  defp answer([], value), do: {:ok, value}
  defp answer(faults, _value), do: {:error, Macaw.Layers.Fault.sort(faults)}
end
