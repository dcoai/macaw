defmodule Macaw.ShortFormTest do
  # The short code form (spec/06 §3.8): a surface written in five lines renders, byte for
  # byte, the surface written out.
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Test.Rows

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin, Macaw.Test.Package])
  @sources %{
    "services" =>
      {%Rows{rows: for(i <- 1..5, do: %{"t" => @now, "v" => i * 10.0, "host" => "s#{i}"})}, nil}
  }

  @tag verifies: "surface-build"
  test "tutorial chapter 1's surface in five lines renders what the written-out surface renders" do
    env = [sources: @sources, registry: @registry, now: @now, ceiling: 1_000]

    # The short form: five lines, the source and the host's env aside.
    {:ok, short} =
      "status"
      |> Surface.build!(title: "Service status", cells: [{"macaw.table", source: "services"}])
      |> Surface.show(env)

    {:ok, explicit} =
      Surface.new(
        name: "status",
        title: "Service status",
        layout: {:stack, order: ["table_services"]},
        cells: %{
          "table_services" => %{
            component: "macaw.table",
            slots: %{"rows" => %{source: "services"}}
          }
        }
      )

    {:ok, validated} = Surface.validate(explicit, @registry, @sources)
    written = Surface.render(validated, env)

    assert Phoenix.HTML.safe_to_string(short) == Phoenix.HTML.safe_to_string(written)
    assert Phoenix.HTML.safe_to_string(short) =~ "<td>s5</td>"
  end

  @tag verifies: "surface-build"
  test "build/2 is new/1 of the same keys, cells as {component, opts}, and build!/2 raises" do
    {:ok, built} =
      Surface.build(:status,
        cells: [
          {"test.note", settings: %{"text" => "hi"}},
          {"macaw.table", %{source: "services", fields: %{"columns" => ["host"]}}},
          "test.note"
        ]
      )

    assert {:ok, ^built} =
             Surface.new(
               name: "status",
               cells: [
                 %{component: "test.note", settings: %{"text" => "hi"}},
                 %{
                   component: "macaw.table",
                   source: "services",
                   fields: %{"columns" => ["host"]}
                 },
                 %{component: "test.note"}
               ]
             )

    assert built.layout == {"stack", %{order: ["note", "table_services", "note_2"]}}

    assert Surface.build("status", cells: []) == {:error, [{[:cells], :empty}]}

    assert_raise ArgumentError, ~r/the surface can't be built:\n  cells: /, fn ->
      Surface.build!("status", cells: [])
    end
  end
end
