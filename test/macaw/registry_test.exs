defmodule Macaw.RegistryTest do
  # The registry's host side (spec/12 §1.1).
  use ExUnit.Case, async: true

  alias Macaw.Registry
  alias Macaw.Test.{HookedPackage, Note, Other, OtherPackage, Package}

  @tag verifies: "registry-build"
  test "a registry holds the listed packages' components by name, closed to the rest" do
    assert {:ok, registry} = Registry.new([Package, Package])
    assert Registry.packages(registry) == [Package]
    assert Registry.components(registry) == [{"test.note", Note}]
    assert Registry.component(registry, "test.note") == {:ok, Note}
    assert Registry.component(registry, :"test.note") == {:ok, Note}
    assert Registry.component(registry, "test.hooked") == :error
    assert Registry.component(registry, 7) == :error

    assert {:ok, empty} = Registry.new([])
    assert Registry.components(empty) == []
    # Loaded, but its package isn't listed.
    assert Code.ensure_loaded?(Other) and Registry.component(empty, "test.note") == :error

    name = "never_an_atom_#{System.unique_integer([:positive])}"
    assert Registry.component(registry, name) == :error
    assert_raise ArgumentError, fn -> String.to_existing_atom(name) end
  end

  @tag verifies: "registry-faults"
  test "a package's faults and a name two packages share are faults at once; new!/1 raises" do
    assert {:error, faults} = Registry.new([Package, OtherPackage, String])

    assert faults == [
             {[], {:duplicate, "test.note", [{Note, Package}, {Other, OtherPackage}]}},
             {[String], :not_a_package}
           ]

    assert_raise ArgumentError, ~r/can't be built:\n.*test\.note/s, fn ->
      Registry.new!([Package, OtherPackage])
    end

    assert %Registry{} = Registry.new!([Package])

    assert Registry.hooks(Registry.new!([Package])) ==
             {:ok, %{"Note" => {Package, "priv/static/note.js"}}}

    assert {:error, [{[], {:duplicate_hook, "Note", _}}]} =
             Registry.hooks(Registry.new!([Package, HookedPackage]))
  end
end
