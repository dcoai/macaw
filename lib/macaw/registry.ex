defmodule Macaw.Registry do
  @moduledoc """
  A host's registry of components and layouts (spec/12 §1.1): built from the packages the
  host enables and the layouts it adds, and nothing else.

      registry = Macaw.Registry.new!([Macaw.Builtin])
      {:ok, Macaw.Builtin.Table} = Macaw.Registry.component(registry, "macaw.table")

  Closed by default: `new([])` holds nothing, and a component whose package isn't listed is
  unknown though its module is loaded. Names are matched by spelling; no atom is made from a
  document's name. Two components of one name across packages fail at boot, naming both.

  Layouts (`Macaw.Layout`) are closed the same way: a registry holds the built-in layouts
  (`Macaw.Layout.builtins/0`) and the ones `layouts:` lists, and nothing else.
  """

  alias Macaw.Component.Package
  alias Macaw.Layers.{Fault, Names}

  @enforce_keys [:packages, :components, :layouts]
  defstruct [:packages, :components, :layouts]

  @type t :: %__MODULE__{
          packages: [module()],
          components: %{String.t() => module()},
          layouts: %{String.t() => module()}
        }

  @doc """
  The registry of the listed packages: `{:ok, registry}`, or every fault at once, a
  package's own at `[package]` and a name two packages share as `{:duplicate, name,
  [{module, package}, {module, package}]}`.

  `layouts:` the layouts the host adds to the built-in ones, each a module implementing
  `Macaw.Layout`: one that doesn't is `:not_a_layout` at `[:layouts, module]`, and a
  layout name two of them share, or one shares with a built-in, is
  `{:duplicate_layout, name, [module, module]}` at `[:layouts]`.
  """
  @spec new([module()], keyword()) :: {:ok, t()} | {:error, [Fault.t(), ...]}
  def new(packages, opts \\ []) when is_list(packages) and is_list(opts) do
    packages = Enum.uniq(packages)
    {layouts, layout_faults} = build_layouts(Keyword.get(opts, :layouts, []))

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

    case Fault.sort(faults ++ duplicates ++ layout_faults) do
      [] ->
        {:ok,
         %__MODULE__{
           packages: packages,
           components: Map.new(entries, fn {name, module, _package} -> {name, module} end),
           layouts: layouts
         }}

      all ->
        {:error, all}
    end
  end

  # The built-in layouts and the host's, by name: every module a layout, every name once.
  defp build_layouts(added) when is_list(added) do
    added = Enum.uniq(added)
    not_layouts = for m <- added, not layout?(m), do: {[:layouts, m], :not_a_layout}
    modules = Macaw.Layout.builtins() ++ Enum.filter(added, &layout?/1)

    duplicates =
      for {name, [_, _ | _] = same} <- Enum.group_by(modules, & &1.name()),
          do: {[:layouts], {:duplicate_layout, name, same}}

    {Map.new(modules, &{&1.name(), &1}), not_layouts ++ duplicates}
  end

  defp build_layouts(other), do: {%{}, [{[:layouts], {:not_a_list, other}}]}

  # A layout exports every callback of `Macaw.Layout`.
  defp layout?(module) do
    is_atom(module) and Code.ensure_loaded?(module) and
      Enum.all?(Macaw.Layout.callbacks(), fn {f, a} ->
        function_exported?(module, f, a)
      end)
  end

  @doc "The registry of the listed packages, or an `ArgumentError` with every fault: a host's boot."
  @spec new!([module()], keyword()) :: t()
  def new!(packages, opts \\ []) do
    case new(packages, opts) do
      {:ok, registry} ->
        registry

      {:error, faults} ->
        raise ArgumentError,
              "the registry can't be built:\n" <>
                Enum.map_join(faults, "\n", &("  " <> Fault.format(&1)))
    end
  end

  @doc """
  The host's registry from its configuration (spec/12 §1.1): `config :macaw, packages:
  [...], layouts: [...]`, `Macaw.Builtin` always among the packages. Built on its first call
  and kept in `:persistent_term`, rebuilt only when the configuration changes; a host calls
  it as it boots, so a misconfigured package fails the boot as `new!/2` does. A registry
  passed explicitly overrides it wherever one is taken.
  """
  @spec default() :: t()
  def default do
    config =
      {Application.get_env(:macaw, :packages, []), Application.get_env(:macaw, :layouts, [])}

    case :persistent_term.get({__MODULE__, :default}, nil) do
      {^config, registry} ->
        registry

      _none_or_stale ->
        registry = from_config(packages: elem(config, 0), layouts: elem(config, 1))
        :persistent_term.put({__MODULE__, :default}, {config, registry})
        registry
    end
  end

  @doc """
  The registry a configuration names: `packages:`, `Macaw.Builtin` first and always, and
  `layouts:`; an `ArgumentError` with every fault for a bad one, as `new!/2`.
  """
  @spec from_config(keyword()) :: t()
  def from_config(config) when is_list(config) do
    packages = [Macaw.Builtin | List.wrap(Keyword.get(config, :packages, []))]
    new!(packages, layouts: Keyword.get(config, :layouts, []))
  end

  @doc "A component by name, a string or an atom read as its spelling: `{:ok, module}` or `:error`."
  @spec component(t(), String.t() | atom()) :: {:ok, module()} | :error
  def component(%__MODULE__{components: components}, name) do
    case Names.name(name) do
      spelled when is_binary(spelled) -> Map.fetch(components, spelled)
      _ -> :error
    end
  end

  @doc "A layout by name, a string or an atom read as its spelling: `{:ok, module}` or `:error`."
  @spec layout(t(), String.t() | atom()) :: {:ok, module()} | :error
  def layout(%__MODULE__{layouts: layouts}, name) do
    case Names.name(name) do
      spelled when is_binary(spelled) -> Map.fetch(layouts, spelled)
      _ -> :error
    end
  end

  @doc "Every layout, `{name, module}`, in name order."
  @spec layouts(t()) :: [{String.t(), module()}]
  def layouts(%__MODULE__{layouts: layouts}), do: Enum.sort(layouts)

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
