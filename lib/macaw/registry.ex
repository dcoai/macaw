defmodule Macaw.Registry do
  @moduledoc """
  A host's registry of components (spec/12 §1.1): built from the packages the host enables,
  and nothing else.

      registry = Macaw.Registry.new!([Macaw.Builtin])
      {:ok, Macaw.Builtin.Table} = Macaw.Registry.component(registry, "macaw.table")

  Closed by default: `new([])` holds nothing, and a component whose package isn't listed is
  unknown though its module is loaded. Names are matched by spelling; no atom is made from a
  document's name. Two components of one name across packages fail at boot, naming both.
  """

  alias Macaw.Component.Package
  alias Macaw.Layers.{Fault, Names}

  @enforce_keys [:packages, :components]
  defstruct [:packages, :components]

  @type t :: %__MODULE__{packages: [module()], components: %{String.t() => module()}}

  @doc """
  The registry of the listed packages: `{:ok, registry}`, or every fault at once, a
  package's own at `[package]` and a name two packages share as `{:duplicate, name,
  [{module, package}, {module, package}]}`.
  """
  @spec new([module()]) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def new(packages) when is_list(packages) do
    packages = Enum.uniq(packages)

    {entries, faults} =
      Enum.reduce(packages, {[], []}, fn package, {entries, faults} ->
        case Package.components(package) do
          {:ok, components} ->
            {entries ++ for(c <- components, do: {c.name, c.module, package}), faults}

          {:error, own} ->
            {entries, faults ++ for({path, reason} <- own, do: {[package | path], reason})}
        end
      end)

    duplicates =
      for {name, [_, _ | _] = same} <-
            Enum.group_by(entries, &elem(&1, 0), &{elem(&1, 1), elem(&1, 2)}),
          do: {[], {:duplicate, name, same}}

    case Fault.sort(faults ++ duplicates) do
      [] ->
        {:ok,
         %__MODULE__{
           packages: packages,
           components: Map.new(entries, fn {name, module, _package} -> {name, module} end)
         }}

      all ->
        {:error, all}
    end
  end

  @doc "The registry of the listed packages, or an `ArgumentError` with every fault: a host's boot."
  @spec new!([module()]) :: t()
  def new!(packages) do
    case new(packages) do
      {:ok, registry} ->
        registry

      {:error, faults} ->
        raise ArgumentError,
              "the registry can't be built:\n" <>
                Enum.map_join(faults, "\n", &("  " <> Fault.format(&1)))
    end
  end

  @doc "A component by name, a string or an atom read as its spelling: `{:ok, module}` or `:error`."
  @spec component(t(), String.t() | atom()) :: {:ok, module()} | :error
  def component(%__MODULE__{components: components}, name) do
    case Names.name(name) do
      spelled when is_binary(spelled) -> Map.fetch(components, spelled)
      _ -> :error
    end
  end

  @doc "Every component, `{name, module}`, in name order."
  @spec components(t()) :: [{String.t(), module()}]
  def components(%__MODULE__{components: components}), do: Enum.sort(components)

  @doc "The packages, as given, each once."
  @spec packages(t()) :: [module()]
  def packages(%__MODULE__{packages: packages}), do: packages

  @doc "Every hook of the registry's packages (`Macaw.Component.Package.hooks/1`)."
  @spec hooks(t()) :: {:ok, map()} | {:error, [Fault.t(), ...]}
  def hooks(%__MODULE__{packages: packages}), do: Package.hooks(packages)
end
