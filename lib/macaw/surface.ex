defmodule Macaw.Surface do
  @moduledoc """
  A surface: a reusable composed unit of cells in a 12-column grid (spec/06 §3.1).

      {:ok, surface} =
        Macaw.Surface.new(
          name: "service_overview",
          title: "Service overview",
          cells: %{
            "latency" => %{component: "macaw.table", place: %{x: 0, y: 0, w: 6, h: 4},
                           slots: %{"rows" => %{source: "latency"}}}
          }
        )

  A surface is a document whose value is a term, read from JSON through the kernel's gates
  and stacked as a fragment:

    * its value is `%{version: v, surface: node}` (`to_map/1`), judged as terms by
      `from_map/1`; its settings and params are the terms they are, checked against the
      component's and the sources' parameter types by `validate/3`;
    * the JSON form, `{"$version": v, "surface": {…}}`, is an adapter at the edge:
      `to_json/1` writes it, refusing at its path a value JSON can't hold, and `from_json/2`
      reads it back through every gate (the version, the limits, the migration), then
      `new/1`;
    * as a fragment type, `cells` is a `:union` by name and every other key an `:override`,
      so a layer adds or replaces cells by name and overrides the title.

  Names are strings, an atom read as its spelling; no atom is made from a document.
  """

  @behaviour Macaw.Layers.Document
  @behaviour Macaw.Layers.Version
  @behaviour Macaw.Layers.Form
  @behaviour Macaw.Layers.Fragment

  import Kernel, except: [node: 1]

  alias Macaw.Layers.{Document, Fault, Form, Names, Version}
  alias Macaw.Layers.Color.Form, as: ColorForm
  alias Macaw.Surface.{Cell, Words}

  @enforce_keys [:name, :cells]
  defstruct name: nil, title: nil, layout: :grid, cells: %{}

  @type t :: %__MODULE__{
          name: String.t(),
          title: String.t() | nil,
          layout: :grid,
          cells: %{String.t() => Cell.t()}
        }

  @keys [:name, :title, :layout, :cells]
  @name ~r/\A[a-z][a-z0-9_]*\z/

  @doc """
  A surface from a keyword list or a map with atom keys: `{:ok, surface}` or every fault
  at once, by path from the surface, in the kernel's order.
  """
  @spec new(keyword() | map()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def new(attrs) when is_list(attrs) do
    if Keyword.keyword?(attrs),
      do: new(Map.new(attrs)),
      else: {:error, [{[], {:type, :map}}]}
  end

  def new(%{} = attrs) when not is_struct(attrs) do
    unknown = for key <- Map.keys(attrs), key not in @keys, do: {[key], :unknown_key}
    {name, n} = name(Map.get(attrs, :name))
    {title, t} = title(Map.get(attrs, :title))
    {layout, l} = layout(Map.get(attrs, :layout, :grid))
    {cells, c} = cells(Map.get(attrs, :cells))

    case Fault.sort(unknown ++ n ++ t ++ l ++ c) do
      [] -> {:ok, %__MODULE__{name: name, title: title, layout: layout, cells: cells}}
      faults -> {:error, faults}
    end
  end

  def new(_other), do: {:error, [{[], {:type, :map}}]}

  defp name(nil), do: {nil, [{[:name], :required}]}

  defp name(name) do
    spelled = Names.name(name)

    if is_binary(spelled) and Regex.match?(@name, spelled),
      do: {spelled, []},
      else: {nil, [{[:name], {:type, :name}}]}
  end

  defp title(nil), do: {nil, []}
  defp title(title) when is_binary(title) and title != "", do: {title, []}
  defp title(_other), do: {nil, [{[:title], {:type, :string}}]}

  defp layout(layout) do
    if Names.name(layout) == "grid",
      do: {:grid, []},
      else: {:grid, [{[:layout], {:unknown_layout, layout}}]}
  end

  defp cells(nil), do: {%{}, [{[:cells], :required}]}

  defp cells(%{} = cells) when not is_struct(cells) and map_size(cells) == 0,
    do: {%{}, [{[:cells], :empty}]}

  defp cells(%{} = cells) when not is_struct(cells) do
    Enum.reduce(cells, {%{}, []}, fn {name, attrs}, {acc, faults} ->
      spelled = Names.name(name)

      cond do
        not (is_binary(spelled) and Regex.match?(@name, spelled)) ->
          {acc, faults ++ [{[:cells, name], {:type, :name}}]}

        true ->
          case Cell.new(attrs) do
            {:ok, %Cell{place: nil} = cell} ->
              {Map.put(acc, spelled, cell), faults ++ [{[:cells, spelled, :place], :required}]}

            {:ok, cell} ->
              {Map.put(acc, spelled, cell), faults}

            {:error, more} ->
              {acc, faults ++ for({path, reason} <- more, do: {[:cells, spelled | path], reason})}
          end
      end
    end)
  end

  defp cells(_other), do: {%{}, [{[:cells], {:type, :map}}]}

  # -- validation --------------------------------------------------------------------------

  @doc """
  The static pass over a surface (spec/06 §3.4), with the host's registry and its sources
  by name, each `{source, context}`: `{:ok, %Macaw.Surface.Validated{}}` or every fault at
  once, by path from the surface. No I/O but each source's `describe`, and no viewer.
  """
  @spec validate(t(), Macaw.Registry.t(), %{String.t() => {Macaw.Data.Source.t(), term()}}) ::
          {:ok, Macaw.Surface.Validated.t()} | {:error, [Fault.t(), ...]}
  def validate(%__MODULE__{} = surface, %Macaw.Registry{} = registry, sources),
    do: Macaw.Surface.Validated.validate(surface, registry, sources)

  # -- fetching and rendering ---------------------------------------------------------------

  @doc """
  Each cell's deliveries and drawn state (spec/06 §3.5): `%{cell => %{deliveries:, drawn:}}`.
  `env`: `sources:` (as given to `validate/3`), `now:` and `ceiling:` (required),
  `viewer:` (`nil`), `width:` (`1200`), `row_height:` (`64`), `timeout:` (`5_000` ms).
  Each fetch runs bounded in a process of its own, so it never blocks or crashes the caller.
  """
  @spec fetch(Macaw.Surface.Validated.t(), keyword()) :: %{String.t() => map()}
  defdelegate fetch(validated, env), to: Macaw.Surface.Fetch

  @doc """
  The surface's markup (spec/06 §3.6), a safe value: its title at `heading_level:` (`2`),
  then its cells in reading order, in `mode:` (`:socketless`), with `theme:`, `now:`,
  `width:` and `row_height:` as for fetching.
  """
  @spec render(Macaw.Surface.Validated.t(), map(), keyword()) :: Phoenix.HTML.safe()
  defdelegate render(validated, fetched, env), to: Macaw.Surface.Render

  @doc "Fetches and renders in one call: `render(validated, fetch(validated, env), env)`."
  @spec render(Macaw.Surface.Validated.t(), keyword()) :: Phoenix.HTML.safe()
  def render(%Macaw.Surface.Validated{} = validated, env),
    do: render(validated, fetch(validated, env), env)

  # -- the forms ---------------------------------------------------------------------------

  @doc """
  The surface as its node: its keys, each cell as its map, every name a string and every
  setting and param the term it is.
  """
  @spec node(t()) :: map()
  def node(%__MODULE__{} = surface) do
    %{name: surface.name, layout: surface.layout, cells: Map.new(surface.cells, &cell_node/1)}
    |> then(fn node -> if surface.title, do: Map.put(node, :title, surface.title), else: node end)
  end

  defp cell_node({name, %Cell{} = cell}) do
    node = %{
      component: cell.component,
      kind: cell.kind,
      settings: cell.settings,
      slots:
        Map.new(cell.slots, fn {slot, binding} ->
          {slot, %{source: binding.source, fields: binding.fields, params: binding.params}}
        end)
    }

    {name, if(cell.place, do: Map.put(node, :place, cell.place), else: node)}
  end

  @doc "`%{surface: node}`: the surface as a fragment."
  @spec fragment(t()) :: %{surface: map()}
  def fragment(%__MODULE__{} = surface), do: %{surface: node(surface)}

  @doc "`%{version: current, surface: node}`: the surface's value as a document."
  @spec to_map(t()) :: %{version: pos_integer(), surface: map()}
  def to_map(%__MODULE__{} = surface), do: %{version: current(), surface: node(surface)}

  @doc """
  The JSON document, `{:ok, json}`, stamped `"$version"`, written by the JSON adapter
  (`Macaw.Layers.Form`): a name as its string, a color by its tags, a time as `$time`, a
  point as `$point`, an atom as `$atom`. A value JSON can't hold is refused at its path,
  `{:type, :term}`, and a map key in a setting or param that isn't a string
  `{:type, :name}`.
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, [Fault.t(), ...]}
  def to_json(%__MODULE__{} = surface), do: Form.to_json(fragment(surface), __MODULE__)

  @doc """
  The surface a document value holds, judged as terms, or every fault: the version first,
  so nothing of a newer document is judged, then the envelope, then `new/1`. No form is
  written or read, so no limit applies: the limits bound what reading an encoding costs
  (`from_json/2`).
  """
  @spec from_map(term()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def from_map(document) when is_map(document) and not is_struct(document) do
    {version, value} = Map.pop(document, :version, current())

    with {:ok, _version} <- Version.check(%{Version.stamp() => version}, __MODULE__),
         {:ok, %{surface: node}} <- Document.check(value, __MODULE__) do
      new(node)
    end
  end

  def from_map(_other), do: {:error, [{[], {:type, :map}}]}

  @doc """
  The surface a JSON document holds: read through the JSON adapter
  (`Macaw.Layers.Form.read/3`: every gate, the version, the limits and the migration, then
  the value, judged), then `new/1`. `limits:` as `Macaw.Layers.Form.gates/3` takes them;
  `vocabulary:` the atoms a setting or param may spell beyond the document's own words,
  since no other atom is made from a document.
  """
  @spec from_json(String.t(), keyword()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def from_json(json, opts \\ []) when is_binary(json) do
    with {:ok, %{surface: node}} <-
           Form.read(json, __MODULE__, Keyword.take(opts, [:limits, :vocabulary])),
         do: new(node)
  end

  # -- the behaviors -----------------------------------------------------------------------

  @impl Version
  def current, do: 1

  # The line is at its first version, so no step exists yet.
  @impl Version
  def step(document, _from), do: {:ok, document}

  @doc false
  # The envelope's value: a surface node, and nothing else.
  @impl Document
  def validate(document) do
    unknown = Document.unknown_keys(document, [:surface])

    surface =
      case Map.fetch(document, :surface) do
        :error -> [{[:surface], :required}]
        {:ok, node} when is_map(node) -> []
        {:ok, _other} -> [{[:surface], {:type, :map}}]
      end

    case unknown ++ surface do
      [] -> :ok
      faults -> {:error, Fault.sort(faults)}
    end
  end

  @impl Form
  def tags, do: Macaw.Surface.Tags
  @impl Form
  def keys, do: Words.keys()
  @impl Form
  def atoms, do: Words.atoms()

  # The surface's names are strings in every name map; a setting's or param's value is data,
  # so its maps are name maps at every depth.
  @impl Form
  def name_map?([:surface, :cells]), do: true
  def name_map?([:surface, :cells, _cell, :slots]), do: true
  def name_map?([:surface, :cells, _cell, :slots, _slot, :fields]), do: true
  def name_map?([:surface, :cells, _cell, :slots, _slot, :params | _]), do: true
  def name_map?([:surface, :cells, _cell, :settings | _]), do: true
  def name_map?(_path), do: false

  # A point is `$point`, a color by the colors' own tags (`Macaw.Layers.Color.Form`).
  @impl Form
  def encode_value({lon, lat}) when is_number(lon) and is_number(lat),
    do: {:ok, %{"$point" => [lon, lat]}}

  def encode_value(term), do: ColorForm.encode_value(term)

  @impl Form
  def decode_value("$point", [lon, lat]) when is_number(lon) and is_number(lat),
    do: {:ok, {lon, lat}}

  def decode_value("$point", _other), do: :default
  def decode_value(tag, payload), do: ColorForm.decode_value(tag, payload)

  @impl Macaw.Layers.Fragment
  def root, do: :surface_document

  @impl Macaw.Layers.Fragment
  def key(:surface_document, :surface), do: %{merge: :override, node: :surface}
  def key(:surface_document, :version), do: %{merge: :override}
  def key(:surface, :cells), do: %{merge: :union}
  def key(:surface, key) when key in [:name, :title, :layout], do: %{merge: :override}
  def key(_kind, _key), do: nil

  @impl Macaw.Layers.Fragment
  def kinds, do: [:surface]

  @impl Macaw.Layers.Fragment
  def wrapper(:surface), do: :surface
  def wrapper(_key), do: nil

  @impl Macaw.Layers.Fragment
  def place(:surface, contribution, _key), do: {:ok, contribution}
end
