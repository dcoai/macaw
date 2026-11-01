defmodule Macaw.Grid do
  @moduledoc """
  The grid a surface places its cells on (spec/06 §3.3), the built-in layout `:grid`
  (`Macaw.Layout`): 12 columns, or 6 or 24 by `{:grid, columns: n}`.

  Places are `%{x, y, w, h}` in integer units: `x` from 0 to one less than the columns,
  `w` from 1 with `x + w` at most the columns, `y` from 0, `h` from 1, and `y + h` at most
  `rows/0`. Reading order is by `y`, then `x`, then name, and is the DOM order. Placement
  is by classes from one static stylesheet, never inline style:

      iex> Macaw.Grid.classes(%{x: 0, y: 2, w: 6, h: 3})
      "mw-cell mw-col-1 mw-span-6 mw-row-3 mw-rows-3"
  """

  @behaviour Macaw.Layout

  @columns 12
  @widths [6, 12, 24]
  @rows 64
  @breakpoint "40rem"

  @type place :: %{x: non_neg_integer(), y: non_neg_integer(), w: pos_integer(), h: pos_integer()}

  @place_keys [:x, :y, :w, :h]

  # -- the layout ---------------------------------------------------------------------------

  @impl Macaw.Layout
  def name, do: "grid"

  @impl Macaw.Layout
  # `columns`, one of `widths/0`, 12 when not given (spec/06 §3.3).
  def options(given) when is_map(given) or is_list(given) do
    given = Map.new(given)

    unknown =
      for key <- Map.keys(given), key != :columns, do: {[:layout, :options, key], :unknown_key}

    {columns, c} =
      case Map.fetch(given, :columns) do
        :error -> {@columns, []}
        {:ok, n} when n in @widths -> {n, []}
        {:ok, _other} -> {@columns, [{[:layout, :options, :columns], {:enum, @widths}}]}
      end

    case unknown ++ c do
      [] -> {:ok, %{columns: columns}}
      faults -> {:error, Macaw.Layers.Fault.sort(faults)}
    end
  end

  @impl Macaw.Layout
  # A place is four integers, `x`, `y`, `w` and `h`; a cell on a grid has one.
  def place(nil), do: {:error, [{[], :required}]}

  def place(%{} = place) when not is_struct(place) do
    unknown = for key <- Map.keys(place), key not in @place_keys, do: {[key], :unknown_key}

    values =
      for key <- @place_keys,
          fault <-
            (case Map.fetch(place, key) do
               {:ok, n} when is_integer(n) -> []
               {:ok, _other} -> [{[key], {:type, :integer}}]
               :error -> [{[key], :required}]
             end),
          do: fault

    case unknown ++ values do
      [] -> {:ok, Map.take(place, @place_keys)}
      faults -> {:error, faults}
    end
  end

  def place(_other), do: {:error, [{[], {:type, :map}}]}

  @doc "`faults/1` on the options' columns."
  @impl Macaw.Layout
  @spec faults(%{String.t() => %{place: place()}}, map()) :: [Macaw.Layers.Fault.t()]
  def faults(cells, options), do: placement(cells, columns(options))

  @impl Macaw.Layout
  def order(cells, _options), do: order(cells)

  @impl Macaw.Layout
  def container(options) do
    case columns(options) do
      @columns -> "mw-grid"
      n -> "mw-grid mw-grid-#{n}"
    end
  end

  @impl Macaw.Layout
  def classes(place, _options), do: classes(place)

  @doc "A place's declared size on the options' columns: `{w * width / columns, h * row_height}`."
  @impl Macaw.Layout
  @spec size(place(), map(), number(), number()) :: {number(), number()}
  def size(%{w: w, h: h}, options, width, row_height) when width > 0 and row_height > 0,
    do: {w * width / columns(options), h * row_height}

  @impl Macaw.Layout
  # One sheet serves every width, so its address is one whatever a surface chooses.
  def stylesheet(_options), do: stylesheet()

  defp columns(%{columns: n}), do: n
  defp columns(_options), do: @columns

  # -- the grid's own -----------------------------------------------------------------------

  @doc "The grid's columns when a surface chooses none, 12."
  @spec columns() :: pos_integer()
  def columns, do: @columns

  @doc "The widths a grid may have, in columns: 6, 12 and 24, so its stylesheet is static."
  @spec widths() :: [pos_integer(), ...]
  def widths, do: @widths

  @doc "The most rows a grid places a cell in, 64, so every placement has a class."
  @spec rows() :: pos_integer()
  def rows, do: @rows

  @doc """
  The faults of the cells' places on 12 columns, each at `[:cells, name, :place]`: a bound
  broken is `{:out_of_bounds, what, value}` (`what` one of `:x`, `:w`, `:x_plus_w`, `:y`,
  `:h`, `:y_plus_h`); two cells overlapping is `{:overlap, other}` at the later one in
  reading order. `cells` maps names to anything with a `place`. `faults/2` takes the
  grid's options, its columns among them.
  """
  @spec faults(%{String.t() => %{place: place()}}) :: [Macaw.Layers.Fault.t()]
  def faults(cells) when is_map(cells), do: placement(cells, @columns)

  defp placement(cells, columns) do
    bounds =
      for {name, %{place: place}} <- cells, {what, value} <- broken(place, columns) do
        {[:cells, name, :place], {:out_of_bounds, what, value}}
      end

    ordered = order(cells)

    overlaps =
      for {later, i} <- Enum.with_index(ordered),
          earlier <- Enum.take(ordered, i),
          overlap?(cells[earlier].place, cells[later].place),
          do: {[:cells, later, :place], {:overlap, earlier}}

    Macaw.Layers.Fault.sort(bounds ++ overlaps)
  end

  defp broken(%{x: x, y: y, w: w, h: h}, columns) do
    Enum.reject(
      [
        (x < 0 or x >= columns) && {:x, x},
        (w < 1 or w > columns) && {:w, w},
        x + w > columns && {:x_plus_w, x + w},
        y < 0 && {:y, y},
        h < 1 && {:h, h},
        y + h > @rows && {:y_plus_h, y + h}
      ],
      &(&1 == false)
    )
  end

  defp overlap?(a, b),
    do: a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h

  @doc "The cells' names in reading order: by `y`, then `x`, then name."
  @spec order(%{String.t() => %{place: place()}}) :: [String.t()]
  def order(cells) when is_map(cells) do
    cells
    |> Enum.sort_by(fn {name, %{place: %{x: x, y: y}}} -> {y, x, name} end)
    |> Enum.map(&elem(&1, 0))
  end

  @doc """
  A place's classes: the cell, its column and span, its row and rows, the same on every
  width; the container's class sets the width (`container/1`).
  """
  @spec classes(place()) :: String.t()
  def classes(%{x: x, y: y, w: w, h: h}),
    do: "mw-cell mw-col-#{x + 1} mw-span-#{w} mw-row-#{y + 1} mw-rows-#{h}"

  @doc """
  A place's declared size in CSS pixels on 12 columns: its share of the surface's width
  and its rows' height, `{w * width / 12, h * row_height}`. `size/4` takes the grid's
  options, its columns among them.
  """
  @spec size(place(), number(), number()) :: {number(), number()}
  def size(place, width, row_height), do: size(place, %{columns: @columns}, width, row_height)

  @doc """
  The grid's one static stylesheet, for every width: the grid (12 columns, and `.mw-grid-6`
  and `.mw-grid-24` for the others), a rule per column start and column span up to the
  widest, per row start and row span, and the container query that stacks every cell into
  reading order when the surface is narrower than 40rem.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    widest = Enum.max(@widths)

    [
      ".mw-surface{container-type:inline-size}\n",
      ".mw-grid{display:grid;grid-template-columns:repeat(#{@columns},minmax(0,1fr));",
      "grid-auto-rows:minmax(var(--mw-grid-row,4rem),auto);gap:var(--mw-grid-gap,1rem)}\n",
      for(
        n <- @widths -- [@columns],
        do: ".mw-grid-#{n}{grid-template-columns:repeat(#{n},minmax(0,1fr))}\n"
      ),
      for(i <- 1..widest, do: ".mw-col-#{i}{grid-column-start:#{i}}\n"),
      for(i <- 1..widest, do: ".mw-span-#{i}{grid-column-end:span #{i}}\n"),
      for(i <- 1..@rows, do: ".mw-row-#{i}{grid-row-start:#{i}}\n"),
      for(i <- 1..@rows, do: ".mw-rows-#{i}{grid-row-end:span #{i}}\n"),
      "@container (max-width: #{@breakpoint}){.mw-grid>.mw-cell{grid-column:1/-1;grid-row:auto}}\n"
    ]
    |> IO.iodata_to_binary()
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())
end
