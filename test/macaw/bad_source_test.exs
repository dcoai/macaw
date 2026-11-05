defmodule Macaw.BadSourceTest do
  # A malformed entry in `sources:` is a fault at its binding's source, or an invalid cell at
  # fetch, and never a raise (spec/06 §3.4, §3.5, #267).
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Test.Rows

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin])
  @env [now: @now, ceiling: 100]

  @malformed [
    {:not_a_source, nil},
    {{:ok, %Rows{rows: []}}, nil},
    :not_a_tuple,
    {~D[2026-01-01], nil},
    {%Rows{rows: []}, nil, :extra},
    {%{__struct__: :no_such_module}, nil}
  ]

  defp good, do: %{"x" => {%Rows{rows: [%{"t" => @now, "v" => 1.0}]}, nil}}

  defp shorthand do
    {:ok, surface} =
      Surface.new(name: "s", cells: [%{component: "macaw.table", name: "c", source: "x"}])

    surface
  end

  defp slotted do
    {:ok, surface} =
      Surface.new(
        name: "s",
        cells: [%{component: "macaw.table", name: "c", slots: %{"rows" => %{source: "x"}}}]
      )

    surface
  end

  @tag verifies: "validate-bad-source"
  test "a malformed entry is {:bad_source, name} at the binding's source" do
    for entry <- @malformed do
      assert Surface.validate(shorthand(), @registry, %{"x" => entry}) ==
               {:error, [{[:cells, "c", :source], {:bad_source, "x"}}]}

      assert Surface.validate(slotted(), @registry, %{"x" => entry}) ==
               {:error, [{[:cells, "c", :slots, "rows", :source], {:bad_source, "x"}}]}

      assert Surface.show(shorthand(), [sources: %{"x" => entry}, registry: @registry] ++ @env) ==
               {:error, [{[:cells, "c", :source], {:bad_source, "x"}}]}
    end
  end

  @tag verifies: "validate-bad-source"
  test "the fault names the source and never echoes the entry" do
    {:error, faults} =
      Surface.validate(shorthand(), @registry, %{"x" => {{:ok, "s3cret"}, "s3cret"}})

    refute inspect(faults) =~ "s3cret"
  end

  @tag verifies: "validate-bad-source"
  test "a source not in the map stays unknown, and sources that aren't a map are a fault" do
    assert Surface.validate(shorthand(), @registry, %{}) ==
             {:error, [{[:cells, "c", :source], {:unknown_source, "x"}}]}

    for sources <- [:nope, [], ~D[2026-01-01]] do
      assert Surface.validate(shorthand(), @registry, sources) ==
               {:error, [{[:sources], {:type, :map}}]}
    end
  end

  @tag verifies: "fetch-bad-source"
  test "a source gone or malformed by fetch draws its cell invalid, with the caller alive" do
    {:ok, validated} = Surface.validate(shorthand(), @registry, good())

    for sources <- [%{}, :nope] ++ Enum.map(@malformed, &%{"x" => &1}) do
      env = [sources: sources] ++ @env
      assert %{"c" => %{drawn: :invalid}} = Surface.fetch(validated, env)
      assert {:safe, _} = Surface.render(validated, env)
    end

    assert %{"c" => %{drawn: :invalid}} = Surface.fetch(validated, @env)
  end

  @tag verifies: "fetch-bad-source"
  test "one bad source leaves another cell's fetch alone" do
    {:ok, surface} =
      Surface.new(
        name: "s",
        cells: [
          %{component: "macaw.table", name: "a", source: "x"},
          %{component: "macaw.table", name: "b", source: "y"}
        ]
      )

    sources = Map.put(good(), "y", {%Rows{rows: [%{"t" => @now, "v" => 1.0}]}, nil})
    {:ok, validated} = Surface.validate(surface, @registry, sources)

    fetched = Surface.fetch(validated, [sources: %{sources | "y" => :nope}] ++ @env)
    assert fetched["a"].drawn == :live
    assert fetched["b"].drawn == :invalid
  end
end
