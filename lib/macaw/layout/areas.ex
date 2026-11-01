defmodule Macaw.Layout.Areas do
  @moduledoc """
  Named regions from a template (spec/06 §3.3), the built-in layout `:areas`, as CSS's
  `grid-template-areas` lays them out:

      {:areas, template: [["header", "header"], ["nav", "main"]]}

  Each row of the template names the area of each of its columns, `nil` for a column no
  area holds, every row as wide as the first. An area is the rectangle of the columns that
  name it. A cell's place is `%{area: "main"}`, one cell to an area, and reading order is
  the order each area first appears in the template, row by row.

  Its stylesheet is generated per template and served by its content address: the
  template's classes carry the digest of its value, so two templates never share a rule
  and one template always has one sheet.

      iex> {:ok, options} = Macaw.Layout.Areas.options(template: [["a", "b"]])
      iex> Macaw.Layout.Areas.container(options) =~ ~r/\\Amw-areas mw-areas-[0-9a-f]{12}\\z/
      true
  """

  @behaviour Macaw.Layout

  alias Macaw.Layers.{Document, Fault, Names}

  @name ~r/\A[a-z][a-z0-9_]*\z/
  @rows 64
  @columns 24
  @breakpoint "40rem"

  @impl Macaw.Layout
  def name, do: "areas"

  @impl Macaw.Layout
  # `template`, required: rows of area names (or `nil`), each as wide as the first, every
  # area a rectangle; at most 64 rows of at most 24 columns.
  def options(given) when is_map(given) or is_list(given) do
    given = Map.new(given)
    at = [:layout, :options, :template]

    unknown =
      for key <- Map.keys(given), key != :template, do: {[:layout, :options, key], :unknown_key}

    {template, t} =
      case Map.fetch(given, :template) do
        :error -> {[], [{at, :required}]}
        {:ok, [_ | _] = rows} -> template(rows, at)
        {:ok, _other} -> {[], [{at, {:type, :template}}]}
      end

    case unknown ++ t do
      [] -> {:ok, %{template: template}}
      faults -> {:error, Fault.sort(faults)}
    end
  end

  defp template(rows, at) do
    shape =
      for {row, i} <- Enum.with_index(rows),
          fault <- row_faults(row, at ++ [i]),
          do: fault

    spelled = if shape == [], do: Enum.map(rows, fn row -> Enum.map(row, &spell/1) end), else: []

    faults =
      cond do
        shape != [] -> shape
        length(rows) > @rows -> [{at, {:limit, :rows, @rows, length(rows)}}]
        length(hd(rows)) > @columns -> [{at, {:limit, :columns, @columns, length(hd(rows))}}]
        true -> widths(spelled, at) ++ rectangles(spelled, at)
      end

    {spelled, faults}
  end

  defp row_faults([_ | _] = row, at) do
    for {entry, j} <- Enum.with_index(row),
        not (entry == nil or name?(spell(entry))),
        do: {at ++ [j], {:type, :name}}
  end

  defp row_faults(_other, at), do: [{at, {:type, {:list, :name}}}]

  defp spell(nil), do: nil
  defp spell(entry), do: Names.name(entry)

  defp name?(name), do: is_binary(name) and Regex.match?(@name, name)

  # Every row as wide as the first.
  defp widths([first | _] = rows, at) do
    width = length(first)

    for {row, i} <- Enum.with_index(rows),
        length(row) != width,
        do: {at ++ [i], {:width, width, length(row)}}
  end

  # Each area is the rectangle its cells span: every column of its bounding box names it.
  defp rectangles(rows, at) do
    if widths(rows, at) != [] do
      []
    else
      for {name, spots} <- spots(rows),
          not rectangle?(rows, name, spots),
          do: {at, {:not_rectangle, name}}
    end
  end

  defp spots(rows) do
    for {row, i} <- Enum.with_index(rows),
        {name, j} <- Enum.with_index(row),
        name != nil,
        reduce: %{} do
      acc -> Map.update(acc, name, [{i, j}], &[{i, j} | &1])
    end
  end

  defp rectangle?(rows, name, spots) do
    {{r0, r1}, {c0, c1}} = bounds(spots)

    Enum.all?(r0..r1, fn i ->
      Enum.all?(c0..c1, fn j -> rows |> Enum.at(i) |> Enum.at(j) == name end)
    end)
  end

  defp bounds(spots) do
    {rs, cs} = Enum.unzip(spots)
    {Enum.min_max(rs), Enum.min_max(cs)}
  end

  @impl Macaw.Layout
  # A place names an area: `%{area: name}`; a cell under areas has one.
  def place(nil), do: {:error, [{[], :required}]}

  def place(%{} = place) when not is_struct(place) do
    unknown = for key <- Map.keys(place), key != :area, do: {[key], :unknown_key}

    area =
      case Map.fetch(place, :area) do
        :error ->
          {:error, [{[:area], :required}]}

        {:ok, given} ->
          if name?(Names.name(given)),
            do: {:ok, Names.name(given)},
            else: {:error, [{[:area], {:type, :name}}]}
      end

    case {unknown, area} do
      {[], {:ok, name}} -> {:ok, %{area: name}}
      {faults, {:ok, _name}} -> {:error, faults}
      {faults, {:error, more}} -> {:error, faults ++ more}
    end
  end

  def place(_other), do: {:error, [{[], {:type, :map}}]}

  @impl Macaw.Layout
  # An area the template doesn't name is `{:unknown_area, name}`; a second cell in an
  # area `{:taken, other}` at the later one, by name.
  def faults(cells, %{template: template}) do
    areas = template |> spots() |> Map.keys()

    unknown =
      for {name, %{place: %{area: area}}} <- cells,
          area not in areas,
          do: {[:cells, name, :place, :area], {:unknown_area, area}}

    taken =
      for {_area, [_ | _] = names} <- Enum.group_by(cells, &elem(&1, 1).place.area, &elem(&1, 0)),
          [first | rest] = Enum.sort(names),
          later <- rest,
          do: {[:cells, later, :place, :area], {:taken, first}}

    Fault.sort(unknown ++ taken)
  end

  @impl Macaw.Layout
  # The order each area first appears in the template, row by row.
  def order(cells, %{template: template}) do
    first = template |> List.flatten() |> Enum.reject(&is_nil/1) |> Enum.uniq()
    rank = Map.new(Enum.with_index(first))

    cells
    |> Enum.sort_by(fn {name, %{place: %{area: area}}} ->
      {Map.get(rank, area, length(first)), name}
    end)
    |> Enum.map(&elem(&1, 0))
  end

  @impl Macaw.Layout
  def container(options), do: "mw-areas " <> class(options)

  @impl Macaw.Layout
  def classes(%{area: area}, _options), do: "mw-cell mw-area-" <> area

  @impl Macaw.Layout
  # An area's share of the width by its columns, and its rows' height.
  def size(%{area: area}, %{template: template}, width, row_height)
      when width > 0 and row_height > 0 do
    case Map.fetch(spots(template), area) do
      {:ok, spots} ->
        {{r0, r1}, {c0, c1}} = bounds(spots)
        {(c1 - c0 + 1) * width / length(hd(template)), (r1 - r0 + 1) * row_height}

      :error ->
        {width, row_height}
    end
  end

  @impl Macaw.Layout
  @doc """
  The template's stylesheet: the container's areas and columns, each area's rule under the
  template's class, and the container query that stacks the areas in reading order when
  the surface is narrower than 40rem.
  """
  @spec stylesheet(%{template: [[String.t() | nil]]}) :: String.t()
  def stylesheet(%{template: template} = options) do
    scope = "." <> class(options)

    rows =
      Enum.map_join(template, " ", fn row ->
        ~s(") <> Enum.map_join(row, " ", &(&1 || ".")) <> ~s(")
      end)

    areas = template |> List.flatten() |> Enum.reject(&is_nil/1) |> Enum.uniq()

    [
      ".mw-surface{container-type:inline-size}\n",
      scope,
      "{display:grid;grid-template-areas:#{rows};",
      "grid-template-columns:repeat(#{length(hd(template))},minmax(0,1fr));",
      "grid-auto-rows:minmax(var(--mw-grid-row,4rem),auto);gap:var(--mw-grid-gap,1rem)}\n",
      for(a <- areas, do: "#{scope}>.mw-area-#{a}{grid-area:#{a}}\n"),
      "@container (max-width: #{@breakpoint}){#{scope}{grid-template-areas:none;",
      "grid-template-columns:minmax(0,1fr)}#{scope}>.mw-cell{grid-area:auto}}\n"
    ]
    |> IO.iodata_to_binary()
  end

  @doc "The template's stylesheet path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path(%{template: [[String.t() | nil]]}) :: String.t()
  def stylesheet_path(options), do: Macaw.Component.Stylesheet.path(stylesheet(options))

  # The template's class: the first twelve hex digits of its value's digest.
  defp class(%{template: template}),
    do: "mw-areas-" <> binary_part(Document.digest(template), 0, 12)
end
