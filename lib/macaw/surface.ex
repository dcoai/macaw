defmodule Macaw.Surface do
  @moduledoc """
  A surface: a reusable composed unit of cells, laid out by its layout (spec/06 §3.1,
  §3.3), the 12-column grid by default.

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
  alias Macaw.Layout
  alias Macaw.Layers.Color.Form, as: ColorForm
  alias Macaw.Surface.{Cell, Words}

  @enforce_keys [:name, :cells]
  defstruct name: nil, title: nil, layout: :grid, cells: %{}

  @type t :: %__MODULE__{
          name: String.t(),
          title: String.t() | nil,
          layout: Macaw.Layout.spec(),
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
    {given, order, o} = listed(Map.get(attrs, :cells))
    {layout_given, d} = placement(Map.get(attrs, :layout), given, order)
    {layout, module, l} = layout(layout_given)
    {cells, c} = cells(given, if(d == [], do: module))

    case Fault.sort(unknown ++ n ++ t ++ o ++ d ++ l ++ c) do
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

  # The layout as the surface holds it, the built-in layout that judges its places now
  # (nil for one only a registry knows, judged at validation), and its faults. The grid
  # with no options is `:grid`, as it always was; a built-in layout with options holds
  # them checked (`{"stack", %{order: ["a", "b"]}}`, every name a string); a layout only a
  # registry knows holds its name, a string, and its options as given.
  defp layout(given) do
    case Layout.split(given) do
      {:error, faults} ->
        {:grid, nil, faults}

      {:ok, {"grid", options}} when options == %{} ->
        {:grid, Layout.builtin("grid"), []}

      {:ok, {name, options}} ->
        case Layout.builtin(name) do
          nil ->
            {if(options == %{}, do: name, else: {name, options}), nil, []}

          module ->
            case module.options(options) do
              {:ok, checked} -> {{name, checked}, module, []}
              {:error, faults} -> {{name, options}, nil, faults}
            end
        end
    end
  end

  # Cells given as a list (spec/06 §3.2): each named by its `name`, or by a name derived
  # from its component and its source, and the list's order kept. A map is as it is.
  defp listed(cells) when is_list(cells) and cells != [] do
    attrs = cells |> Enum.with_index() |> Enum.map(&cell_attrs/1)
    explicit = for {%{name: name}, _i} <- attrs, name != nil, do: Names.name(name)

    Enum.reduce(attrs, {%{}, [], []}, fn {a, i}, {named, order, faults} ->
      case cell_name(a, explicit, order) do
        {:ok, name} when is_map_key(named, name) ->
          {named, order, faults ++ [{[:cells, i, :name], {:duplicate, name}}]}

        {:ok, name} ->
          {Map.put(named, name, Map.delete(a, :name)), order ++ [name], faults}

        {:error, reason} ->
          {named, order, faults ++ [{[:cells, i | reason_path(reason)], reason_of(reason)}]}
      end
    end)
  end

  defp listed([]), do: {%{}, nil, []}
  defp listed(cells), do: {cells, nil, []}

  defp cell_attrs({attrs, i}) when is_list(attrs) do
    if Keyword.keyword?(attrs), do: {Map.new(attrs), i}, else: {attrs, i}
  end

  defp cell_attrs({attrs, i}), do: {attrs, i}

  # A listed cell's name: its own, a name; else one derived; else why it has none.
  defp cell_name(%{} = attrs, explicit, earlier) when not is_struct(attrs) do
    case Map.get(attrs, :name) do
      nil ->
        case derive(attrs, explicit, earlier) do
          nil when is_map_key(attrs, :component) -> {:error, {[:name], :required}}
          nil -> {:error, {[:component], :required}}
          name -> {:ok, name}
        end

      given ->
        spelled = Names.name(given)

        if is_binary(spelled) and Regex.match?(@name, spelled),
          do: {:ok, spelled},
          else: {:error, {[:name], {:type, :name}}}
    end
  end

  defp cell_name(_other, _explicit, _earlier), do: {:error, {[], {:type, :map}}}

  defp reason_path({path, _reason}), do: path
  defp reason_of({_path, reason}), do: reason

  # `<component's last word>_<source>` (`table_services`), the last word alone with no
  # source, numbered `_2`, `_3`, … past every name taken: the explicit names, then the
  # names derived before it in list order.
  defp derive(attrs, explicit, earlier) do
    word = attrs |> Map.get(:component) |> Names.name() |> last_word()
    base = if source = source_of(attrs), do: "#{word}_#{source}", else: word
    taken = MapSet.new(explicit ++ earlier)

    if is_binary(base) and Regex.match?(@name, base),
      do:
        Enum.find(
          [base | for(n <- 2..(MapSet.size(taken) + 2), do: "#{base}_#{n}")],
          &(not MapSet.member?(taken, &1))
        ),
      else: nil
  end

  defp last_word(component) when is_binary(component),
    do: component |> String.split(".") |> List.last()

  defp last_word(_other), do: nil

  # The source a cell reads: its one slot's.
  defp source_of(attrs) do
    case Map.get(attrs, :slots) do
      %{} = slots when map_size(slots) == 1 ->
        [binding] = Map.values(slots)
        if is_map(binding), do: binding |> Map.get(:source) |> Names.name(), else: nil

      _other ->
        nil
    end
  end

  # The layout a surface takes when it names none (spec/06 §3.3): listed cells with no
  # place are stacked in the list's order, and a stack or a flow named with no order takes
  # the list's. A list of placed cells is a grid, as a map's is; one that places some cells
  # and not others is `:place_mixed`, never a guess, and its places are not judged.
  defp placement(nil, _cells, nil), do: {:grid, []}

  defp placement(nil, cells, order) do
    case cells |> Map.values() |> Enum.map(&placed?/1) |> Enum.uniq() do
      [false] -> {{:stack, order: order}, []}
      [true] -> {:grid, []}
      _mixed -> {:grid, [{[:cells], :place_mixed}]}
    end
  end

  defp placement(given, _cells, nil), do: {given, []}

  defp placement(given, _cells, order) do
    case Layout.split(given) do
      {:ok, {name, options}} when name in ["stack", "flow"] and not is_map_key(options, :order) ->
        {{name, Map.put(options, :order, order)}, []}

      _other ->
        {given, []}
    end
  end

  defp placed?(%{place: place}) when place != nil, do: true
  defp placed?(_attrs), do: false

  defp cells(nil, _layout), do: {%{}, [{[:cells], :required}]}

  defp cells(%{} = cells, _layout) when not is_struct(cells) and map_size(cells) == 0,
    do: {%{}, [{[:cells], :empty}]}

  defp cells(%{} = cells, layout) when not is_struct(cells) do
    Enum.reduce(cells, {%{}, []}, fn {name, attrs}, {acc, faults} ->
      spelled = Names.name(name)

      cond do
        not (is_binary(spelled) and Regex.match?(@name, spelled)) ->
          {acc, faults ++ [{[:cells, name], {:type, :name}}]}

        true ->
          case Cell.new(attrs, layout) do
            # Whether a cell needs a place is its layout's: the grid's does.
            {:ok, %Cell{place: nil} = cell} when layout != nil ->
              absent =
                case layout.place(nil) do
                  {:ok, _none} -> []
                  {:error, more} -> for {p, r} <- more, do: {[:cells, spelled, :place | p], r}
                end

              {Map.put(acc, spelled, cell), faults ++ absent}

            {:ok, cell} ->
              {Map.put(acc, spelled, cell), faults}

            {:error, more} ->
              {acc, faults ++ for({path, reason} <- more, do: {[:cells, spelled | path], reason})}
          end
      end
    end)
  end

  defp cells(_other, _layout), do: {%{}, [{[:cells], {:type, :map}}]}

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

  @doc """
  The stylesheet a validated surface's layout places its cells by, and its path, its content
  address: `{path, css}`, for the host to serve from `'self'` (spec/06 §3.3). The grid's,
  the stack's and the flow's are each one sheet; an areas layout's is its template's.
  """
  @spec stylesheet(Macaw.Surface.Validated.t()) :: {String.t(), String.t()}
  def stylesheet(%Macaw.Surface.Validated{layout: {layout, options}}) do
    css = layout.stylesheet(options)
    {Macaw.Component.Stylesheet.path(css), css}
  end

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
  The surface a document value holds, judged as terms, or every fault by path from the
  document: the version first, so nothing of a newer document is judged, then the
  envelope, then `new/1` (its faults under `:surface`). No form is written or read, so no
  limit applies: the limits bound what reading an encoding costs (`from_json/2`).
  """
  @spec from_map(term()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def from_map(document) when is_map(document) and not is_struct(document) do
    {version, value} = Map.pop(document, :version, current())

    with {:ok, _version} <- Version.check(%{Version.stamp() => version}, __MODULE__),
         {:ok, %{surface: node}} <- Document.check(value, __MODULE__) do
      surface(node)
    end
  end

  def from_map(_other), do: {:error, [{[], {:type, :map}}]}

  @doc """
  The surface a JSON document holds: read through the JSON adapter
  (`Macaw.Layers.Form.read/3`: every gate, the version, the limits and the migration, then
  the value, judged), then `new/1`, every fault by path from the document as `from_map/1`
  gives them. `limits:` as `Macaw.Layers.Form.gates/3` takes them;
  `vocabulary:` the atoms a setting or param may spell beyond the document's own words,
  since no other atom is made from a document.
  """
  @spec from_json(String.t(), keyword()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def from_json(json, opts \\ []) when is_binary(json) do
    with {:ok, %{surface: node}} <-
           Form.read(json, __MODULE__, Keyword.take(opts, [:limits, :vocabulary])),
         do: surface(node)
  end

  # A document's surface node, built: `new/1`'s faults are by path from the surface, so a
  # reader's are put under the document's `:surface`, where the node sits (spec/06 §3.1).
  defp surface(node) do
    case new(node) do
      {:ok, surface} -> {:ok, surface}
      {:error, faults} -> {:error, for({path, reason} <- faults, do: {[:surface | path], reason})}
    end
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

  # A point is `$point`, a layout with options `$layout` (its name and its options, a node
  # of the surface's keys), a color by the colors' own tags (`Macaw.Layers.Color.Form`).
  @impl Form
  def encode_value({lon, lat}) when is_number(lon) and is_number(lat),
    do: {:ok, %{"$point" => [lon, lat]}}

  def encode_value({name, options}) when is_binary(name) and is_map(options) do
    case Form.encode_term(options, __MODULE__, [{:tag, "$layout"}, 1]) do
      {:ok, form} -> {:ok, %{"$layout" => [name, form]}}
      {:error, _faults} -> :default
    end
  end

  def encode_value(term), do: ColorForm.encode_value(term)

  @impl Form
  def decode_value("$point", [lon, lat]) when is_number(lon) and is_number(lat),
    do: {:ok, {lon, lat}}

  def decode_value("$point", _other), do: :default

  def decode_value("$layout", [name, options]) when is_binary(name) and is_map(options),
    do: {:ok, {name, options}}

  def decode_value("$layout", _other), do: :default
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
