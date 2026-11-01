defmodule Macaw.Grid do
  @moduledoc """
  The 12-column grid a surface places its cells on (spec/06 §3.3), the built-in layout
  `:grid` (`Macaw.Layout`).

  Places are `%{x, y, w, h}` in integer units: `x` from 0 to 11, `w` from 1 to 12 with
  `x + w` at most 12, `y` from 0, `h` from 1, and `y + h` at most `rows/0`. Reading order is
  by `y`, then `x`, then name, and is the DOM order. Placement is by classes from one static
  stylesheet, never inline style:

      iex> Macaw.Grid.classes(%{x: 0, y: 2, w: 6, h: 3})
      "mw-cell mw-col-1 mw-span-6 mw-row-3 mw-rows-3"
  """

  @behaviour Macaw.Layout

  @columns 12
  @rows 64
  @breakpoint "40rem"

  @type place :: %{x: non_neg_integer(), y: non_neg_integer(), w: pos_integer(), h: pos_integer()}

  @place_keys [:x, :y, :w, :h]

  # -- the layout ---------------------------------------------------------------------------

  @impl Macaw.Layout
  def name, do: "grid"

  @impl Macaw.Layout
  # The grid takes no options yet (spec/06 §3.3).
  def options(given) when given == %{} or given == [], do: {:ok, %{}}

  def options(given) when is_map(given) or is_list(given),
    do: {:error, for({key, _value} <- given, do: {[:layout, :options, key], :unknown_key})}

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

  @impl Macaw.Layout
  def faults(cells, _options), do: faults(cells)

  @impl Macaw.Layout
  def order(cells, _options), do: order(cells)

  @impl Macaw.Layout
  def classes(place, _options), do: classes(place)

  @impl Macaw.Layout
  def size(place, _options, width, row_height), do: size(place, width, row_height)

  @impl Macaw.Layout
  def stylesheet(_options), do: stylesheet()

  # -- the grid's own -----------------------------------------------------------------------

  @doc "The grid's columns, 12."
  @spec columns() :: pos_integer()
  def columns, do: @columns

  @doc "The most rows a grid places a cell in, 64, so every placement has a class."
  @spec rows() :: pos_integer()
  def rows, do: @rows

  @doc """
  The faults of the cells' places, each at `[:cells, name, :place]`: a bound broken is
  `{:out_of_bounds, what, value}` (`what` one of `:x`, `:w`, `:x_plus_w`, `:y`, `:h`,
  `:y_plus_h`); two cells overlapping is `{:overlap, other}` at the later one in reading
  order. `cells` maps names to anything with a `place`.
  """
  @spec faults(%{String.t() => %{place: place()}}) :: [Macaw.Layers.Fault.t()]
  def faults(cells) when is_map(cells) do
    bounds =
      for {name, %{place: place}} <- cells, {what, value} <- broken(place) do
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

  defp broken(%{x: x, y: y, w: w, h: h}) do
    Enum.reject(
      [
        (x < 0 or x >= @columns) && {:x, x},
        (w < 1 or w > @columns) && {:w, w},
        x + w > @columns && {:x_plus_w, x + w},
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

  @doc "A place's classes: the cell, its column and span, its row and rows."
  @spec classes(place()) :: String.t()
  def classes(%{x: x, y: y, w: w, h: h}),
    do: "mw-cell mw-col-#{x + 1} mw-span-#{w} mw-row-#{y + 1} mw-rows-#{h}"

  @doc """
  A place's declared size in CSS pixels: its share of the surface's width and its rows'
  height, `{w * width / 12, h * row_height}`.
  """
  @spec size(place(), number(), number()) :: {number(), number()}
  def size(%{w: w, h: h}, width, row_height) when width > 0 and row_height > 0,
    do: {w * width / @columns, h * row_height}

  @doc """
  The grid's one static stylesheet: the grid, a rule per column start, column span, row
  start and row span, and the container query that stacks every cell into reading order
  when the surface is narrower than 40rem.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    [
      ".mw-surface{container-type:inline-size}\n",
      ".mw-grid{display:grid;grid-template-columns:repeat(#{@columns},minmax(0,1fr));",
      "grid-auto-rows:minmax(var(--mw-grid-row,4rem),auto);gap:var(--mw-grid-gap,1rem)}\n",
      for(i <- 1..@columns, do: ".mw-col-#{i}{grid-column-start:#{i}}\n"),
      for(i <- 1..@columns, do: ".mw-span-#{i}{grid-column-end:span #{i}}\n"),
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
