defmodule Macaw.BadEnvTest do
  # What fetch/2, render/2 and show/2 do with an env's values (spec/00 §4.3, spec/06 §3.5,
  # §3.7, #273): a bad value is an invalid cell or a fault, a limit is never silently off,
  # and a wrong call fails as a wrong call does.
  use ExUnit.Case, async: true

  alias Macaw.{Registry, Surface}
  alias Macaw.Data.{Bounded, Delivery}
  alias Macaw.Test.Rows

  @now ~U[2026-11-01 00:00:00Z]
  @registry Registry.new!([Macaw.Builtin, Macaw.Test.Package])

  # Each is a value that isn't a ceiling. Most order above every number, which is how one
  # came to apply no limit at all: `n > :nope` is false.
  @not_ceilings [:nope, "10", %{}, [], true, {10}, 1.5, 10.0, 0, -1, nil]

  defmodule RaisingDescribe do
    @moduledoc false
    @behaviour Macaw.Data.Source
    defstruct []

    @impl true
    def describe(_source, _context), do: raise("a bug in the host's source")

    @impl true
    def fetch(_source, _request), do: {:error, :never}
  end

  defp rows, do: for(s <- 1..500, do: %{"t" => DateTime.add(@now, s), "v" => s * 1.0})
  defp sources, do: %{"a" => {%Rows{rows: rows(), notify: self(), supports: [:budget]}, nil}}

  # A table asking for more rows than any ceiling here, and a cell with no slots.
  defp surface do
    {:ok, surface} =
      Surface.new(
        name: "s",
        cells: [
          %{component: "macaw.table", name: "c", source: "a"},
          %{component: "test.note", name: "n", settings: %{"text" => "hi"}}
        ]
      )

    surface
  end

  defp validated do
    {:ok, validated} = Surface.validate(surface(), @registry, sources())
    validated
  end

  defp env(overrides \\ []),
    do: Keyword.merge([sources: sources(), now: @now, ceiling: 100], overrides)

  @tag verifies: "fetch-bad-env"
  test "a ceiling that isn't a positive integer draws the cell invalid, with nothing fetched" do
    validated = validated()

    for ceiling <- @not_ceilings do
      fetched = Surface.fetch(validated, env(ceiling: ceiling, width: 24_000))
      assert fetched["c"] == %{deliveries: %{}, drawn: :invalid}, inspect(ceiling)
      refute_received {:fetched, _slot, _budget, _params}
    end
  end

  @tag verifies: "fetch-bad-env"
  test "a positive integer ceiling still clamps, so the refusal costs a good host nothing" do
    fetched = Surface.fetch(validated(), env(ceiling: 3, width: 24_000))
    assert %{deliveries: %{"rows" => %Delivery{} = delivery}, drawn: :capped} = fetched["c"]
    assert length(Delivery.rows!(delivery)) == 3
    assert_received {:fetched, "rows", 3, _params}
  end

  @tag verifies: "fetch-bad-env"
  test "a bad width, row height, timeout or now draws the cell invalid with the caller alive" do
    validated = validated()

    for {key, values} <- [
          width: [:nope, nil, 0, -1, "1200"],
          row_height: [:nope, nil, 0, -1, "64"],
          timeout: [:nope, nil, -1, 1.5, :infinity],
          now: [:nope, nil, "2026-11-01", ~D[2026-11-01]]
        ],
        value <- values do
      fetched = Surface.fetch(validated, env([{key, value}]))
      assert fetched["c"].drawn == :invalid, inspect({key, value})
      refute_received {:fetched, _slot, _budget, _params}
    end
  end

  @tag verifies: "fetch-bad-env"
  test "a cell with no slots has nothing to refuse, and draws as it always does" do
    assert Surface.fetch(validated(), env(ceiling: :nope))["n"] == %{
             deliveries: %{},
             drawn: :live
           }
  end

  @tag verifies: "fetch-bad-env"
  test "render/2 draws what fetching refused for the values only fetching reads" do
    validated = validated()

    for bad <- [[ceiling: :nope], [ceiling: 0], [timeout: :nope]] do
      html = validated |> Surface.render(env(bad)) |> Phoenix.HTML.safe_to_string()
      assert html =~ "mw-drawn-invalid", inspect(bad)
      assert html =~ "hi"
    end
  end

  @tag verifies: "errors-values"
  test "a wrong call fails as a wrong call does: a required key left out, or no struct" do
    validated = validated()
    assert_raise KeyError, fn -> Surface.fetch(validated, Keyword.delete(env(), :now)) end
    assert_raise KeyError, fn -> Surface.fetch(validated, Keyword.delete(env(), :ceiling)) end
    assert_raise KeyError, fn -> Surface.render(validated, Keyword.delete(env(), :now)) end
    assert_raise KeyError, fn -> Surface.render(validated, Keyword.delete(env(), :ceiling)) end
    assert_raise FunctionClauseError, fn -> Surface.fetch(validated, not_a_struct()) end
    assert_raise FunctionClauseError, fn -> Surface.fetch(not_a_struct(), env()) end
    assert_raise FunctionClauseError, fn -> Surface.render(not_a_struct(), env()) end

    assert_raise FunctionClauseError, fn ->
      Surface.validate(not_a_struct(), @registry, sources())
    end

    assert_raise FunctionClauseError, fn ->
      Surface.validate(surface(), not_a_struct(), sources())
    end
  end

  @tag verifies: "errors-values"
  test "render/3 has no fault to answer, so a value it can't build a cell from is a wrong call" do
    validated = validated()
    fetched = Surface.fetch(validated, env())

    for bad <-
          [[now: :nope], [width: 0], [row_height: :nope], [mode: :nope], [theme: :nope]] ++
            [[heading_level: :nope]] do
      call = fn -> Surface.render(validated, fetched, env(bad)) end
      assert {:down, _reason} = Bounded.run(call, timeout: 1_000), inspect(bad)
    end
  end

  # Opaque to the type checker, which would otherwise refuse these wrong calls at compile time.
  defp not_a_struct, do: Process.get(:not_a_struct, :nope)

  @tag verifies: "validate-bad-source"
  test "a describe that raises is the host's bug and fails validate/3, where fetch/2 isolates" do
    assert_raise RuntimeError, "a bug in the host's source", fn ->
      Surface.validate(surface(), @registry, %{"a" => {%RaisingDescribe{}, nil}})
    end

    assert_raise RuntimeError, "a bug in the host's source", fn ->
      Surface.show(surface(),
        registry: @registry,
        sources: %{"a" => {%RaisingDescribe{}, nil}},
        now: @now,
        ceiling: 100
      )
    end
  end

  defp show(overrides), do: Surface.show(surface(), [registry: @registry] ++ env(overrides))

  @tag verifies: "surface-show"
  test "show/2 answers every bad value of its env by key, all at once" do
    for ceiling <- @not_ceilings -- [nil] do
      assert show(ceiling: ceiling) == {:error, [{[:ceiling], {:type, :pos_integer}}]}
    end

    assert show(now: :nope) == {:error, [{[:now], {:type, :time}}]}
    assert show(width: 0) == {:error, [{[:width], {:type, :pos_number}}]}
    assert show(row_height: :nope) == {:error, [{[:row_height], {:type, :pos_number}}]}
    assert show(timeout: -1) == {:error, [{[:timeout], {:type, :non_neg_integer}}]}
    assert show(mode: :nope) == {:error, [{[:mode], {:unknown_mode, :nope}}]}
    assert show(theme: :nope) == {:error, [{[:theme], :not_a_theme}]}
    assert show(heading_level: 9) == {:error, [{[:heading_level], :not_a_level}]}

    assert show(ceiling: :nope, now: nil, theme: :nope) ==
             {:error,
              [
                {[:ceiling], {:type, :pos_integer}},
                {[:now], {:type, :time}},
                {[:theme], :not_a_theme}
              ]}
  end

  @tag verifies: "surface-show"
  test "show/2 answers an env that isn't a keyword list, improper lists included" do
    fault = {:error, [{[], {:type, :keyword}}]}
    assert Surface.show(surface(), [1, {:sources, %{}}, {:ceiling, 1}]) == fault
    assert Surface.show(surface(), [{:ceiling, 1} | :improper]) == fault
  end

  @tag verifies: "surface-show"
  test "show/2 still renders over every value of its env that is good" do
    assert {:ok, {:safe, _html}} =
             show(width: 800.5, row_height: 40, timeout: 0, mode: :live, heading_level: 3)
  end
end
