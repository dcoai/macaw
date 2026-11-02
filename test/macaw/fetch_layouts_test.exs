defmodule Macaw.FetchLayoutsTest do
  # Every built-in layout's bound cells are fetched at their declared size (spec/06 §3.5),
  # a place or none (#232): a layout added to the built-ins is covered here by itself.
  use ExUnit.Case, async: true

  alias Macaw.{Component, Layout, Registry, Surface}
  alias Macaw.Builtin.Table
  alias Macaw.Test.Rows

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin])

  # A layout, and one table cell under it, bound to a source.
  defp under(Macaw.Grid), do: {:grid, %{place: %{x: 0, y: 0, w: 6, h: 4}}}
  defp under(Macaw.Layout.Stack), do: {{:stack, order: ["t"]}, %{}}
  defp under(Macaw.Layout.Flow), do: {{:flow, order: ["t"]}, %{}}

  defp under(Macaw.Layout.Areas),
    do: {{:areas, template: [["t", "t", "side"]]}, %{place: %{area: "t"}}}

  # A source answering tuple rows with no names, which finishing can't order by a field.
  defmodule Nameless do
    @behaviour Macaw.Data.Source
    defstruct []
    @impl true
    def describe(_source, _context),
      do: Macaw.Data.Source.Description.new(schema: Rows.default_schema())

    @impl true
    def fetch(_source, _request), do: Macaw.Data.Delivery.new([{1, 2.0, "a"}, {2, 1.0, "b"}])
  end

  @tag verifies: "fetch-drawn"
  test "a delivery finishing refuses draws its cell invalid, never a crash" do
    sources = %{"lat" => {%Nameless{}, nil}}

    cell = %{
      component: "macaw.table",
      source: "lat",
      settings: %{"sort" => "v", "order" => "desc"}
    }

    {:ok, s} = Surface.new(name: "ops", cells: [cell])
    {:ok, v} = Surface.validate(s, @registry, sources)

    assert %{"table_lat" => %{drawn: :invalid, deliveries: %{}}} =
             Surface.fetch(v, sources: sources, now: @now, ceiling: 1_000)
  end

  @tag verifies: "fetch-budgets"
  test "a bound cell under every built-in layout is fetched at its declared size and draws live" do
    rows = for i <- 1..50, do: %{"t" => @now, "v" => i * 1.0, "host" => "h#{i}"}
    sources = %{"lat" => {%Rows{rows: rows, notify: self(), name: "lat"}, nil}}

    for layout <- Layout.builtins() do
      {given, extra} = under(layout)
      cell = Map.merge(%{component: "macaw.table", slots: %{"rows" => %{source: "lat"}}}, extra)
      {:ok, s} = Surface.new(name: "ops", layout: given, cells: %{"t" => cell})
      {:ok, v} = Surface.validate(s, @registry, sources)
      {^layout, options} = v.layout

      fetched = Surface.fetch(v, sources: sources, now: @now, ceiling: 1_000)
      assert %{"rows" => _delivery} = fetched["t"].deliveries, inspect(layout)
      assert fetched["t"].drawn in [:live, :capped], inspect(layout)

      size = layout.size(s.cells["t"].place, options, 1200, 64)
      {:ok, budget} = Component.budget(Table, "rows", v.cells["t"].settings, size)
      assert_received {:fetched, "lat", ^budget, _params}
    end
  end
end
