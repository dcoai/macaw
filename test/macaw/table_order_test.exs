defmodule Macaw.TableOrderTest do
  # The table asks its source for its sort order (spec/05 §6.1, spec/06 §3.5, #221), so a
  # delivery capped at its budget holds the first rows in that order, not a sorted sample.
  use ExUnit.Case, async: true

  alias Macaw.{Component, Registry, Surface}
  alias Macaw.Builtin.Table
  alias Macaw.Data.Delivery
  alias Macaw.Test.Rows

  @now ~U[2026-11-02 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin])
  # Fifty rows whose v is a permutation of 0..49, so every order is told apart.
  @rows for i <- 0..49, do: %{"t" => @now, "v" => rem(i * 37, 50) * 1.0, "host" => "h#{i}"}

  defp table(sort, order \\ "desc", source \\ "lat"),
    do: %{component: "macaw.table", source: source, settings: %{"sort" => sort, "order" => order}}

  defp fetch(cells, supports) do
    sources = %{
      "lat" => {%Rows{rows: @rows, supports: supports, notify: self(), name: "lat"}, nil}
    }

    {:ok, s} = Surface.new(name: "ops", cells: cells)
    {:ok, v} = Surface.validate(s, @registry, sources)
    Surface.fetch(v, sources: sources, now: @now, ceiling: 1_000)
  end

  defp budget, do: elem(Component.budget(Table, "rows", %{"sort" => "v"}, {1200, 256}), 1)
  defp vs(delivery), do: delivery |> Delivery.rows!() |> Enum.map(& &1["v"])

  @tag verifies: "table-order"
  test "the table's order is its sort column in its direction, none without a sort" do
    assert Component.order(Table, "rows", %{"sort" => "v", "order" => "desc"}) ==
             {:ok, [{"v", :desc}]}

    assert Component.order(Table, "rows", %{"sort" => "host", "order" => "asc"}) ==
             {:ok, [{"host", :asc}]}

    assert Component.order(Table, "rows", %{"sort" => "", "order" => "asc"}) == {:ok, []}
  end

  @tag verifies: "table-order"
  test "a capped table holds the first rows in its sort order, whoever orders them" do
    n = budget()
    assert n < length(@rows)
    top = @rows |> Enum.map(& &1["v"]) |> Enum.sort(:desc) |> Enum.take(n)

    # A source that orders and caps itself; one that does neither, so the runtime orders
    # every row and keeps the head.
    for {supports, by} <- [{[:order, :budget], :source}, {[], :runtime}] do
      %{"table_lat" => %{deliveries: %{"rows" => delivery}}} = fetch([table("v")], supports)
      assert vs(delivery) == top, inspect(supports)
      assert delivery.served.ordered == by
    end

    assert_received {:ordered, "lat", [{"v", :desc}]}

    # A source that caps but can't order cut its rows first: the rows are in order, and the
    # delivery says they are a sample, never claiming to be the first.
    %{"table_lat" => %{deliveries: %{"rows" => sample}}} = fetch([table("v")], [:budget])
    assert sample.served.ordered == :sample
    assert vs(sample) == Enum.sort(vs(sample), :desc)
    refute vs(sample) == top
  end

  @tag verifies: "table-order"
  test "slots pool only when they ask for the same order, and an order the schema can't answer is invalid" do
    same = fetch([table("v"), table("v")], [:budget])
    assert Map.keys(same) == ["table_lat", "table_lat_2"]
    assert_received {:fetched, "lat", _, _}
    refute_received {:fetched, "lat", _, _}

    fetch([table("v"), table("host", "asc")], [:budget])
    assert_received {:fetched, "lat", _, _}
    assert_received {:fetched, "lat", _, _}

    # A sort naming no field of the schema draws the cell invalid, and fetches nothing.
    assert %{"table_lat" => %{drawn: :invalid, deliveries: %{}}} =
             fetch([table("nope")], [:budget])

    refute_received {:fetched, "lat", _, _}
  end
end
