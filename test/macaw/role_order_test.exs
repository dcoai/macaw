defmodule Macaw.RoleOrderTest do
  # An order naming a role reaches its source as the field bound to it (spec/06 §3.5, #258).
  use ExUnit.Case, async: true

  alias Macaw.Data.Schema
  alias Macaw.Registry
  alias Macaw.Surface
  alias Macaw.Test.Rows

  @now ~U[2026-11-04 12:00:00Z]

  defmodule Newest do
    @moduledoc false
    # Asks for its slot's rows newest first, by whatever field the role its `by` names is
    # bound to: `t`, the window field, or `k`, any time.
    use Macaw.Component, name: "test.newest", kinds: [:content]

    alias Macaw.Component.Drawn
    alias Macaw.Data.Delivery

    @impl true
    def parameters, do: %{"by" => %{type: :text, default: "t"}}

    @impl true
    def declarations(_settings) do
      {:ok,
       slots: %{
         "rows" => %{
           requires: %{
             "t" => %{type: :time, window: true},
             "k" => %{type: :time, optional: true},
             "v" => %{type: :number, optional: true}
           }
         }
       }}
    end

    @impl true
    def budget("rows", _settings, _size), do: 2

    @impl true
    def order("rows", %{"by" => by}), do: [{{:role, by}, :desc}]

    @impl true
    def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{} = delivery}})
        when drawn in [:live, :capped] do
      seen = delivery |> Delivery.rows!() |> Enum.map_join(",", &DateTime.to_iso8601(&1["at"]))
      {:safe, "<p>#{seen}</p>"}
    end

    def render(:content, assigns), do: Drawn.render(assigns.drawn, assigns.context)
  end

  defmodule Package do
    @moduledoc false
    def __members__, do: [Newest]
  end

  @schema Schema.new!(%{
            "at" => %{type: :time, window: true},
            "other" => %{type: :time},
            "v" => %{type: :number}
          })

  defp rows do
    for s <- 1..4 do
      at = DateTime.add(@now, s - 10, :second)
      %{"at" => at, "other" => DateTime.add(@now, -s, :second), "v" => s}
    end
  end

  defp source(opts \\ []) do
    {struct!(
       %Rows{schema: @schema, rows: rows(), notify: self(), supports: [:budget, :order]},
       opts
     ), nil}
  end

  defp fetched(cells, sources) do
    {:ok, surface} = Surface.new(name: "s", cells: cells)
    {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin, Package]), sources)
    {v, Surface.fetch(v, sources: sources, now: @now, ceiling: 1_000)}
  end

  @tag verifies: "fetch-role-order"
  test "a role in an order reaches the source as the field bound to it" do
    {_v, _fetched} =
      fetched(
        [
          %{
            component: "test.newest",
            source: "a",
            settings: %{"by" => "k"},
            fields: %{"k" => "other"}
          }
        ],
        %{"a" => source()}
      )

    assert_receive {:ordered, "rows", [{"other", :desc}]}
  end

  @tag verifies: "fetch-role-order"
  test "an unbound window role orders by the schema's window field, and a capped slot holds the newest" do
    sources = %{"a" => source()}
    {v, _fetched} = fetched([%{component: "test.newest", source: "a"}], sources)
    assert_receive {:ordered, "rows", [{"at", :desc}]}

    html =
      v
      |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
      |> Phoenix.HTML.safe_to_string()

    newest = DateTime.add(@now, -6, :second) |> DateTime.to_iso8601()
    second = DateTime.add(@now, -7, :second) |> DateTime.to_iso8601()
    assert html =~ "<p>#{newest},#{second}</p>"
  end

  @tag verifies: "fetch-role-order"
  test "a runtime that orders gives the same newest rows from a source that doesn't" do
    sources = %{"a" => source(supports: [])}
    {v, _fetched} = fetched([%{component: "test.newest", source: "a"}], sources)

    html =
      v
      |> Surface.render(sources: sources, now: @now, ceiling: 1_000)
      |> Phoenix.HTML.safe_to_string()

    newest = DateTime.add(@now, -6, :second) |> DateTime.to_iso8601()
    second = DateTime.add(@now, -7, :second) |> DateTime.to_iso8601()
    assert html =~ "<p>#{newest},#{second}</p>"
  end

  @tag verifies: "fetch-role-order"
  test "two cells whose role orders resolve to one field cost one fetch; different fields, two" do
    cells = [
      %{component: "test.newest", source: "a", name: "x"},
      %{component: "test.newest", source: "a", name: "y", fields: %{"t" => "at"}}
    ]

    fetched(cells, %{"a" => source()})
    assert_receive {:fetched, "rows", _budget, _params}
    refute_receive {:fetched, "rows", _budget, _params}, 50

    cells = [
      %{component: "test.newest", source: "a", name: "x"},
      %{
        component: "test.newest",
        source: "a",
        name: "y",
        settings: %{"by" => "k"},
        fields: %{"k" => "other"}
      }
    ]

    fetched(cells, %{"a" => source()})
    assert_receive {:fetched, "rows", _budget, _params}
    assert_receive {:fetched, "rows", _budget, _params}
  end

  @tag verifies: "fetch-role-order"
  test "a role the binding can't resolve draws the cell invalid, with nothing fetched" do
    {_v, fetched} =
      fetched(
        [%{component: "test.newest", source: "a", name: "x", settings: %{"by" => "nope"}}],
        %{"a" => source()}
      )

    assert fetched["x"].drawn == :invalid
    refute_received {:fetched, "rows", _budget, _params}
  end

  @tag verifies: "fetch-role-order"
  test "a field-keyed order is unchanged" do
    sources = %{
      "a" =>
        {%Rows{
           rows: [%{"t" => @now, "v" => 1.0, "host" => "a"}],
           notify: self(),
           supports: [:budget, :order]
         }, nil}
    }

    {:ok, surface} =
      Surface.new(
        name: "s",
        cells: [
          %{component: "macaw.table", source: "a", settings: %{"sort" => "v", "order" => "desc"}}
        ]
      )

    {:ok, v} = Surface.validate(surface, Registry.new!([Macaw.Builtin]), sources)
    Surface.fetch(v, sources: sources, now: @now, ceiling: 1_000)
    assert_receive {:ordered, "rows", [{"v", :desc}]}
  end
end
