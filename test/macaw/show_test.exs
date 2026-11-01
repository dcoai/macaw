defmodule Macaw.ShowTest do
  # The host's default registry (spec/12 §1.1) and the one-call render (spec/06 §3.7).
  # The application config is the node's, so nothing else may run while it is set.
  use ExUnit.Case, async: false

  alias Macaw.{Registry, Surface}
  alias Macaw.Test.Rows

  # A component that shows the mode its context was given.
  defmodule Mode do
    use Macaw.Component, name: "test.mode", kinds: [:content]

    @impl true
    def render(:content, assigns), do: {:safe, "<p>#{assigns.context.mode}</p>"}
  end

  defmodule ModePackage do
    def __members__, do: [Mode]
  end

  @now ~U[2026-11-01 00:00:00Z]
  @sources %{"lat" => {%Rows{rows: [%{"t" => @now, "v" => 1.0, "host" => "a"}]}, nil}}

  setup do
    saved =
      for key <- [:packages, :layouts, :ceiling], do: {key, Application.fetch_env(:macaw, key)}

    on_exit(fn ->
      for {key, value} <- saved do
        case value do
          {:ok, v} -> Application.put_env(:macaw, key, v)
          :error -> Application.delete_env(:macaw, key)
        end
      end
    end)
  end

  @tag verifies: "registry-default"
  test "the default registry is the configured packages and layouts, Builtin always among them" do
    registry = Registry.from_config(packages: [Macaw.Test.Package])
    assert Registry.packages(registry) == [Macaw.Builtin, Macaw.Test.Package]
    assert {:ok, Macaw.Builtin.Table} = Registry.component(registry, "macaw.table")
    assert {:ok, Macaw.Test.Note} = Registry.component(registry, "test.note")
    assert Registry.packages(Registry.from_config([])) == [Macaw.Builtin]

    assert_raise ArgumentError, ~r/the registry can't be built/, fn ->
      Registry.from_config(packages: [String])
    end

    Application.put_env(:macaw, :packages, [Macaw.Test.Package])
    Application.delete_env(:macaw, :layouts)
    assert Registry.default() == Registry.from_config(packages: [Macaw.Test.Package])

    # A changed configuration is read, never a stale registry.
    Application.put_env(:macaw, :packages, [ModePackage])
    assert {:ok, Mode} = Registry.component(Registry.default(), "test.mode")
    assert Registry.component(Registry.default(), "test.note") == :error

    Application.put_env(:macaw, :packages, [String])
    assert_raise ArgumentError, fn -> Registry.default() end
  end

  @tag verifies: "surface-show"
  test "show/2 renders what validate/3 then render/2 render, given the same now, and answers validation's faults" do
    Application.put_env(:macaw, :packages, [Macaw.Test.Package])
    Application.delete_env(:macaw, :layouts)
    attrs = [name: "ops", cells: [%{component: "macaw.table", source: "lat"}]]

    {:ok, s} = Surface.new(attrs)
    {:ok, v} = Surface.validate(s, Registry.default(), @sources)
    expected = Surface.render(v, sources: @sources, now: @now, ceiling: 1_000)

    env = [sources: @sources, now: @now, ceiling: 1_000]
    assert Surface.show(s, env) == {:ok, expected}
    assert Surface.show({:ok, s}, env) == {:ok, expected}
    assert Surface.show(attrs, env) == {:ok, expected}
    assert Surface.show(s, [{:registry, Registry.from_config([])} | env]) == {:ok, expected}

    # Validation's faults, and new/1's, as they are.
    {:ok, bad} = Surface.new(name: "ops", cells: [%{name: "x", component: "nobody.here"}])
    assert Surface.show(bad, env) == Surface.validate(bad, Registry.default(), @sources)
    assert Surface.show([name: "ops", cells: []], env) == {:error, [{[:cells], :empty}]}

    # The ceiling from the host's configuration, and loudly when there is none.
    Application.put_env(:macaw, :ceiling, 1_000)
    assert Surface.show(s, sources: @sources, now: @now) == {:ok, expected}
    Application.delete_env(:macaw, :ceiling)

    assert_raise ArgumentError, ~r/ceiling/, fn ->
      Surface.show(s, sources: @sources, now: @now)
    end

    # With no now, the call reads the clock once itself.
    assert {:ok, {:safe, _html}} = Surface.show(s, sources: @sources, ceiling: 1_000)
  end

  @tag verifies: "surface-show"
  test "show/2's mode is socketless unless given, and follows a LiveView socket's connection" do
    registry = Registry.new!([ModePackage])
    {:ok, s} = Surface.new(name: "ops", cells: [%{component: "test.mode"}])
    env = [sources: %{}, now: @now, ceiling: 100, registry: registry]

    html = fn extra ->
      {:ok, safe} = Surface.show(s, env ++ extra)
      Phoenix.HTML.safe_to_string(safe)
    end

    assert html.([]) =~ "<p>socketless</p>"
    assert html.(mode: :neutral) =~ "<p>neutral</p>"
    assert html.(socket: %{transport_pid: self()}) =~ "<p>live</p>"
    assert html.(socket: %{transport_pid: nil}) =~ "<p>socketless</p>"
  end
end
