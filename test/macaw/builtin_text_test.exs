defmodule Macaw.Builtin.TextTest do
  # The words the built-in components head a field with (spec/05 §6, #252).
  use ExUnit.Case, async: true

  alias Macaw.Builtin.Text
  alias Macaw.Component.Context

  defp context(schema) do
    {:ok, context} =
      Context.new(
        mode: :socketless,
        instance: "c1",
        size: {300, 128},
        now: ~U[2026-11-03 12:00:00Z],
        schemas: %{"rows" => schema}
      )

    context
  end

  @tag verifies: "table-headers"
  test "a unit is its display symbol with annotations; a field without one has none" do
    schema =
      Macaw.Data.Schema.new!(%{
        "rate" => %{type: :number, label: "Request rate", unit: "{request}/s"},
        "t" => %{type: :number, unit: "Cel"},
        "n" => %{type: :number, label: "Count"}
      })

    c = context(schema)
    assert Text.unit(c, "rows", "rate") == "request/s"
    assert Text.heading(c, "rows", "rate") == "Request rate (request/s)"
    assert Text.heading(c, "rows", "t") == "t (°C)"
    assert Text.unit(c, "rows", "n") == nil
    assert Text.heading(c, "rows", "n") == "Count"
    assert Text.heading(c, "other", "n") == "n"
  end

  @tag verifies: "table-headers"
  test "a code with no symbol is shown as it is" do
    assert {:error, _} = Macaw.Data.Unit.symbol("not a [unit")
    assert Text.symbol("not a [unit") == "not a [unit"
    assert Text.symbol("ms") == "ms"
  end
end
