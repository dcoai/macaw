defmodule Macaw.Layout do
  @moduledoc """
  How a surface lays out its cells (spec/06 §3.3): a behavior, the way a component is one.
  A layout checks its options and each cell's place, gives the placement faults, the
  reading order, each cell's classes and declared size, and its one stylesheet.

  A surface names its layout by `layout`, a name or `{name, options}` (`:grid`). The
  built-in layouts are `builtins/0`; a host's registry holds them and the layouts it adds
  (`Macaw.Registry.new/2`), and nothing else, so a layout no registry holds is
  `{:unknown, :layout}` at `[:layout]` (spec/12 §1.1).

  Every rule a layout keeps is the web's (spec/10): the reading order is the visual order,
  and placement is by classes from a static stylesheet served by its content address,
  never inline style.
  """

  alias Macaw.Layers.{Fault, Names}

  @typedoc "A layout as a surface names it: its name, or its name and options."
  @type spec :: atom() | String.t() | {atom() | String.t(), keyword() | map()}

  @typedoc "A cell as a layout reads it: anything with a `place`."
  @type cells :: %{String.t() => %{place: term()}}

  @doc "The layout's name, as a surface spells it (`\"grid\"`)."
  @callback name() :: String.t()

  @doc """
  The layout's options, checked: `{:ok, options}` or the faults, by path from the options.
  A layout taking no options answers `{:ok, %{}}` for none given.
  """
  @callback options(given :: keyword() | map()) :: {:ok, term()} | {:error, [Fault.t(), ...]}

  @doc """
  A cell's place under this layout, checked: `{:ok, place}` or the faults, by path from
  the place. `nil` is a cell with no place.
  """
  @callback place(given :: term()) :: {:ok, term()} | {:error, [Fault.t(), ...]}

  @doc "The placement faults of the cells, by path from the surface, all at once."
  @callback faults(cells(), options :: term()) :: [Fault.t()]

  @doc "The cells' names in reading order, which is the visual order and the DOM's."
  @callback order(cells(), options :: term()) :: [String.t()]

  @doc "The classes of the element holding the cells, which the layout's stylesheet styles."
  @callback container(options :: term()) :: String.t()

  @doc "A cell's classes, the only way it is placed."
  @callback classes(place :: term(), options :: term()) :: String.t()

  @doc """
  A cell's declared size in CSS pixels, `{width, height}`, from the surface's width and
  row height: what its component lays out at before any measurement.
  """
  @callback size(place :: term(), options :: term(), width :: number(), row_height :: number()) ::
              {number(), number()}

  @doc "The layout's static stylesheet for these options."
  @callback stylesheet(options :: term()) :: String.t()

  @builtins [Macaw.Grid]

  @doc "The callbacks a layout exports, each `{name, arity}`."
  @spec callbacks() :: keyword(non_neg_integer())
  def callbacks,
    do: [
      name: 0,
      options: 1,
      place: 1,
      faults: 2,
      order: 2,
      container: 1,
      classes: 2,
      size: 4,
      stylesheet: 1
    ]

  @doc "The built-in layouts, which every registry holds."
  @spec builtins() :: [module(), ...]
  def builtins, do: @builtins

  @doc "The layout a surface has when it names none, the grid."
  @spec default() :: module()
  def default, do: Macaw.Grid

  @doc "The built-in layout of a name, by spelling, or `nil`."
  @spec builtin(term()) :: module() | nil
  def builtin(name) do
    spelled = Names.name(name)
    Enum.find(@builtins, &(&1.name() == spelled))
  end

  @doc """
  A surface's `layout` split into its name, spelled, and its options as given:
  `{:ok, {name, options}}`, or `{:error, faults}` at `[:layout]` for a value that is
  neither a name nor `{name, options}`.

      iex> Macaw.Layout.split(:grid)
      {:ok, {"grid", %{}}}
      iex> Macaw.Layout.split({"grid", columns: 24})
      {:ok, {"grid", %{columns: 24}}}
  """
  @spec split(term()) :: {:ok, {String.t(), map()}} | {:error, [Fault.t(), ...]}
  def split({name, options})
      when is_list(options) or (is_map(options) and not is_struct(options)) do
    with {:ok, {spelled, %{}}} <- split(name) do
      if is_list(options) and not Keyword.keyword?(options),
        do: {:error, [{[:layout, :options], {:type, :map}}]},
        else: {:ok, {spelled, Map.new(options)}}
    end
  end

  def split(name) do
    case Names.name(name) do
      spelled when is_binary(spelled) and spelled != "" -> {:ok, {spelled, %{}}}
      _other -> {:error, [{[:layout], {:type, :layout}}]}
    end
  end

  @doc """
  The cells' places judged by a layout, and its placement faults: every fault by path from
  the surface, `[:cells, name, :place | path]` for a place and the layout's own for the
  placement. Each place is checked whether or not another fails.
  """
  @spec judge(module(), term(), cells()) :: [Fault.t()]
  def judge(layout, options, cells) when is_atom(layout) and is_map(cells) do
    {placed, faults} =
      Enum.reduce(cells, {%{}, []}, fn {name, cell}, {placed, faults} ->
        case layout.place(cell.place) do
          {:ok, place} ->
            {Map.put(placed, name, %{cell | place: place}), faults}

          {:error, more} ->
            {placed, faults ++ for({path, r} <- more, do: {[:cells, name, :place | path], r})}
        end
      end)

    # Placement is judged over the places that are well formed, so a bad place is named
    # once, at itself, never again as a collision.
    Fault.sort(faults ++ layout.faults(placed, options))
  end
end
