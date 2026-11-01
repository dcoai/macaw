defmodule Macaw.OrderedLayoutTest do
  # The stack and the flow (spec/06 §3.3): cells with no place, in the order the surface
  # gives, which is the DOM order and the visual order (spec/10 §4).
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Layout.{Flow, Stack}
  alias Macaw.Test.Package

  doctest Stack
  doctest Flow

  @registry Registry.new!([Package])
  @now ~U[2026-11-01 00:00:00Z]

  defp note(text), do: %{component: "test.note", settings: %{"text" => text}}
  defp cells, do: %{"a" => note("A"), "b" => note("B"), "c" => note("C")}

  defp render(v),
    do:
      v |> Surface.render(sources: %{}, now: @now, ceiling: 100) |> Phoenix.HTML.safe_to_string()

  @tag verifies: "layout-ordered"
  test "a stack or a flow is in the order given, its DOM order, with no inline style" do
    for {layout, container, class} <- [
          {:stack, "mw-stack", "mw-cell"},
          {:flow, "mw-flow", "mw-cell mw-section"}
        ] do
      {:ok, s} = Surface.new(name: "ops", layout: {layout, order: ["c", :a, "b"]}, cells: cells())
      assert s.layout == {Atom.to_string(layout), %{order: ["c", "a", "b"]}}

      assert {:ok, v} = Surface.validate(s, @registry, %{})
      assert v.order == ["c", "a", "b"]

      html = render(v)
      assert html =~ ~s(<div class="#{container}"><div class="#{class}" id="ops-c">)
      assert [_, c, a, b] = String.split(html, ~s(<div class="#{class}" id="ops-))
      assert c =~ ~s(c"><p>C</p>) and a =~ ~s(a"><p>A</p>) and b =~ ~s(b"><p>B</p>)
      refute html =~ "style"
    end
  end

  @tag verifies: "layout-ordered"
  test "a cell under an ordered layout has no place, and the order names every cell once" do
    with_place = Map.put(cells(), "a", Map.put(note("A"), :place, %{x: 0, y: 0, w: 1, h: 1}))

    assert {:error, [{[:cells, "a", :place], {:not_taken, "stack"}}]} =
             Surface.new(name: "ops", layout: {:stack, order: ["a", "b", "c"]}, cells: with_place)

    assert {:error, [{[:cells, "a", :place], {:not_taken, "flow"}}]} =
             Surface.new(name: "ops", layout: {:flow, order: ["a", "b", "c"]}, cells: with_place)

    # The order is required, a list of names.
    assert {:error, [{[:layout, :options, :order], :required}]} =
             Surface.new(name: "ops", layout: :stack, cells: cells())

    assert {:error, [{[:layout, :options, :order], {:type, {:list, :name}}}]} =
             Surface.new(name: "ops", layout: {:stack, order: "a"}, cells: cells())

    assert {:error, [{[:layout, :options, :order, 1], {:type, :name}}]} =
             Surface.new(name: "ops", layout: {:flow, order: ["a", 7]}, cells: cells())

    assert {:error, [{[:layout, :options, :tall], :unknown_key}]} =
             Surface.new(name: "ops", layout: {:flow, order: ["a"], tall: true}, cells: cells())

    # A name no cell has, one given twice and a cell left out, all at once, at validation.
    {:ok, s} =
      Surface.new(name: "ops", layout: {:stack, order: ["a", "z", "a", "b"]}, cells: cells())

    assert Surface.validate(s, @registry, %{}) ==
             {:error,
              [
                {[:layout, :options, :order], {:missing, "c"}},
                {[:layout, :options, :order, 1], {:unknown_cell, "z"}},
                {[:layout, :options, :order, 2], {:duplicate, "a"}}
              ]}
  end

  @tag verifies: "layout-ordered"
  test "a cell's declared size is the surface's width and four rows; each sheet is served by its address" do
    for layout <- [Stack, Flow] do
      assert layout.size(nil, %{order: []}, 1200, 64) == {1200, 256}
      assert layout.size(nil, %{order: []}, 960, 48) == {960, 192}
      assert layout.stylesheet(%{order: ["a"]}) == layout.stylesheet()
      assert layout.stylesheet_path() == Macaw.Component.Stylesheet.path(layout.stylesheet())
    end

    assert Stack.stylesheet_path() == Macaw.Component.Stylesheet.path(Stack.stylesheet())
    assert Flow.stylesheet_path() == Macaw.Component.Stylesheet.path(Flow.stylesheet())
    assert Stack.stylesheet() =~ ".mw-stack{display:grid;grid-template-columns:minmax(0,1fr);"
    assert Flow.stylesheet() =~ ".mw-flow>.mw-section+.mw-section{margin-block-start:"
  end

  @tag verifies: "layout-ordered"
  test "an ordered layout round-trips through the map and JSON forms" do
    {:ok, s} = Surface.new(name: "ops", layout: {:flow, order: ["b", "a", "c"]}, cells: cells())
    assert {:ok, json} = Surface.to_json(s)

    assert JSON.decode!(json)["surface"]["layout"] == %{
             "$layout" => ["flow", %{"order" => ["b", "a", "c"]}]
           }

    assert Surface.from_json(json) == {:ok, s}
    assert Surface.from_map(Surface.to_map(s)) == {:ok, s}
  end
end
