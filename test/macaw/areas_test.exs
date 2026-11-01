defmodule Macaw.AreasTest do
  # Named regions from a template (spec/06 §3.3): its faults by path, all at once, reading
  # order by the template, and one stylesheet per template served by its address.
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Layout.Areas
  alias Macaw.Test.Package

  doctest Areas

  @registry Registry.new!([Package])
  @now ~U[2026-11-01 00:00:00Z]
  @template [["header", "header", "header"], ["nav", "main", "main"], [nil, "main", "main"]]

  defp at(area, text),
    do: %{component: "test.note", settings: %{"text" => text}, place: %{area: area}}

  defp cells,
    do: %{"top" => at("header", "T"), "side" => at(:nav, "S"), "body" => at("main", "B")}

  defp surface(template \\ @template, cells \\ cells()) do
    {:ok, s} = Surface.new(name: "ops", layout: {:areas, template: template}, cells: cells)
    s
  end

  @tag verifies: "layout-areas"
  test "a template's rows are names as wide as the first, each area a rectangle; every fault at once" do
    assert {:ok, %{template: [["a", nil], ["a", "b"]]}} =
             Areas.options(template: [[:a, nil], ["a", "b"]])

    at = [:layout, :options, :template]

    assert Areas.options([]) == {:error, [{at, :required}]}
    assert Areas.options(template: []) == {:error, [{at, {:type, :template}}]}

    assert Areas.options(template: [["a"], "b"]) ==
             {:error, [{at ++ [1], {:type, {:list, :name}}}]}

    assert Areas.options(template: [["a", "Bad Name", 7]]) ==
             {:error, [{at ++ [0, 1], {:type, :name}}, {at ++ [0, 2], {:type, :name}}]}

    assert Areas.options(template: [["a", "b"], ["a"], ["a", "b", "c"]]) ==
             {:error, [{at ++ [1], {:width, 2, 1}}, {at ++ [2], {:width, 2, 3}}]}

    # An L of "a", and "b" split in two: each area must be one rectangle.
    assert Areas.options(template: [["a", "b"], ["a", "a"], ["b", "c"]]) ==
             {:error, [{at, {:not_rectangle, "a"}}, {at, {:not_rectangle, "b"}}]}

    assert {:error, [{^at, {:limit, :columns, 24, 25}}]} =
             Areas.options(template: [List.duplicate("a", 25)])

    assert {:error, [{^at, {:limit, :rows, 64, 65}}]} =
             Areas.options(template: List.duplicate(["a"], 65))

    assert {:error, [{[:layout, :options, :tint], :unknown_key}]} =
             Areas.options(template: [["a"]], tint: 1)
  end

  @tag verifies: "layout-areas"
  test "a cell names an area the template has, one cell to an area, all faults by path" do
    assert {:error, [{[:cells, "top", :place], :required}]} =
             Surface.new(
               name: "ops",
               layout: {:areas, template: @template},
               cells: %{"top" => %{component: "test.note"}}
             )

    assert {:error, faults} =
             Surface.new(
               name: "ops",
               layout: {:areas, template: @template},
               cells: %{
                 "a" => %{component: "test.note", place: %{x: 0}},
                 "b" => %{component: "test.note", place: %{area: "Main"}}
               }
             )

    assert faults == [
             {[:cells, "a", :place, :area], :required},
             {[:cells, "a", :place, :x], :unknown_key},
             {[:cells, "b", :place, :area], {:type, :name}}
           ]

    s =
      surface(
        @template,
        Map.merge(cells(), %{"extra" => at("main", "E"), "lost" => at("footer", "L")})
      )

    assert Surface.validate(s, @registry, %{}) ==
             {:error,
              [
                {[:cells, "extra", :place, :area], {:taken, "body"}},
                {[:cells, "lost", :place, :area], {:unknown_area, "footer"}}
              ]}
  end

  @tag verifies: "layout-areas"
  test "reading order is each area's first appearance in the template, the DOM order, no inline style" do
    assert {:ok, v} = Surface.validate(surface(), @registry, %{})
    assert v.order == ["top", "side", "body"]
    {Areas, options} = v.layout

    html =
      v |> Surface.render(sources: %{}, now: @now, ceiling: 100) |> Phoenix.HTML.safe_to_string()

    assert html =~
             ~s(<div class="#{Areas.container(options)}"><div class="mw-cell mw-area-header" id="ops-top">)

    assert [_, top, side, body] = String.split(html, ~s(<div class="mw-cell mw-area-))
    assert top =~ "<p>T</p>" and side =~ ~s(nav" id="ops-side"><p>S</p>) and body =~ "<p>B</p>"
    refute html =~ "style"

    # An area's share of the width by its columns, its rows' height.
    assert Areas.size(%{area: "main"}, options, 1200, 64) == {800.0, 128}
    assert Areas.size(%{area: "nav"}, options, 1200, 64) == {400.0, 64}
    assert Areas.size(%{area: "header"}, options, 1200, 64) == {1200.0, 64}
  end

  @tag verifies: "layout-areas"
  test "one template is one stylesheet, served by its address; another template another" do
    {:ok, options} = Areas.options(template: @template)
    css = Areas.stylesheet(options)
    "mw-areas " <> class = Areas.container(options)

    assert css =~
             ~s|.#{class}{display:grid;grid-template-areas:"header header header" "nav main main" ". main main";grid-template-columns:repeat(3,minmax(0,1fr));|

    for area <- ["header", "nav", "main"],
        do: assert(css =~ ".#{class}>.mw-area-#{area}{grid-area:#{area}}")

    assert css =~ "@container (max-width: 40rem){.#{class}{grid-template-areas:none;"
    assert Areas.stylesheet_path(options) == Macaw.Component.Stylesheet.path(css)
    assert Macaw.Component.Stylesheet.fault(css) == nil

    # The same template, given again (its names as atoms), is the same sheet; another is
    # another.
    {:ok, again} =
      Areas.options(
        template: [[:header, :header, :header], [:nav, :main, :main], [nil, :main, :main]]
      )

    assert Areas.stylesheet(again) == css

    {:ok, other} = Areas.options(template: [["nav", "main"]])
    refute Areas.container(other) == Areas.container(options)
    refute Areas.stylesheet_path(other) == Areas.stylesheet_path(options)

    # A host serves the sheet a validated surface's layout uses.
    {:ok, v} = Surface.validate(surface(), @registry, %{})
    assert Surface.stylesheet(v) == {Areas.stylesheet_path(options), css}
  end

  @tag verifies: "layout-areas"
  test "an areas layout round-trips through the map and JSON forms, its empty columns among it" do
    s = surface()
    assert s.layout == {"areas", %{template: @template}}
    assert {:ok, json} = Surface.to_json(s)

    assert JSON.decode!(json)["surface"]["layout"] ==
             %{"$layout" => ["areas", %{"template" => @template}]}

    assert Surface.from_json(json) == {:ok, s}
    assert Surface.from_map(Surface.to_map(s)) == {:ok, s}
  end
end
