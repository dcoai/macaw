defmodule Macaw.StaleTest do
  # A delivery's served.stale draws its cell stale (spec/06 §3.5, #253).
  use ExUnit.Case, async: true

  alias Macaw.Data.{Delivery, Derived, Schema}
  alias Macaw.Data.Derived.Engine
  alias Macaw.Data.Source.Description
  alias Macaw.{Registry, Surface}

  @now ~U[2026-11-04 12:00:00Z]
  @schema Schema.new!(%{"host" => %{type: :category}, "v" => %{type: :number}})
  @rows [%{"host" => "a", "v" => 1}, %{"host" => "b", "v" => 2}]

  defmodule Served do
    @moduledoc false
    # A source answering its rows with the served facts it is given.
    @behaviour Macaw.Data.Source
    defstruct [:schema, rows: [], served: []]

    @impl true
    def describe(%__MODULE__{schema: schema}, _context), do: Description.new(schema: schema)

    @impl true
    def fetch(%__MODULE__{} = source, _request),
      do: Delivery.new(source.rows, served: source.served)
  end

  defp drawn(sources) do
    cells =
      for {name, _source} <- sources,
          do: %{component: "macaw.table", source: name, name: name}

    {:ok, surface} = Surface.new(name: "s", cells: cells)
    {:ok, validated} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)
    fetched = Surface.fetch(validated, sources: sources, now: @now, ceiling: 1_000)
    Map.new(fetched, fn {cell, %{drawn: state}} -> {cell, state} end)
  end

  defp served(rows, facts), do: {%Served{schema: @schema, rows: rows, served: facts}, nil}

  @tag verifies: "fetch-drawn"
  test "stale draws stale, also when capped; empty draws no_data whatever else it says; fresh is unchanged" do
    assert drawn(%{
             "stale" => served(@rows, stale: true),
             "stale_capped" => served(@rows, stale: true, capped: true),
             "stale_empty" => served([], stale: true),
             "capped_empty" => served([], capped: true),
             "capped" => served(@rows, capped: true),
             "fresh" => served(@rows, [])
           }) == %{
             "stale" => :stale,
             "stale_capped" => :stale,
             "stale_empty" => :no_data,
             "capped_empty" => :no_data,
             "capped" => :capped,
             "fresh" => :live
           }
  end

  @tag verifies: "fetch-drawn"
  test "a stale input draws a cell over its derived source stale, and a fresh one live" do
    derived =
      Derived.new!(
        id: :d,
        from: [a: nil],
        schema: %{"n" => %{type: :number}},
        elixir: ~S|fn %{a: a} -> [%{"n" => Enum.count(a)}] end|
      )

    state = fn facts ->
      {:ok, engine} = Engine.new(%{["d"] => derived}, sources: [:a], debounce: 0)
      {:ok, input} = Delivery.new(@rows, served: facts)

      {:ok, engine} =
        engine |> Engine.push(%{a: input}, %{a: @schema}, 0) |> then(&{:ok, Engine.run(&1, 0)})

      {:ok, output} = Engine.source(engine, ["d"])
      drawn(%{"d" => {output, nil}})["d"]
    end

    assert state.(stale: true) == :stale
    assert state.([]) == :live
  end

  @tag verifies: "table-markup"
  test "a stale table draws its notice above its rows" do
    sources = %{"t" => served(@rows, stale: true)}
    {:ok, surface} = Surface.new(name: "s", cells: [%{component: "macaw.table", source: "t"}])
    {:ok, validated} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)

    html =
      validated
      |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
      |> Phoenix.HTML.safe_to_string()

    [notice, rows] = String.split(html, "<table", parts: 2)
    assert notice =~ Macaw.Component.Drawn.words(:stale)
    assert rows =~ "<td>"
  end
end
