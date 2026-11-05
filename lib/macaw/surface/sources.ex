defmodule Macaw.Surface.Sources do
  @moduledoc false
  # A host's `sources:`, read one way by validation and by fetching: an entry is a
  # `{source, context}` whose source is a struct of a module with the source contract's
  # `describe/2` and `fetch/2`. Anything else is `:malformed`, never passed on to a call
  # that would raise, and its contents are never put in a fault.

  alias Macaw.Data.Source

  @spec entry(term(), term()) :: {:ok, Source.t(), term()} | :unknown | :malformed
  def entry(sources, name) when is_map(sources) and not is_struct(sources) do
    case Map.fetch(sources, name) do
      {:ok, {%module{} = source, context}} ->
        if source?(module), do: {:ok, source, context}, else: :malformed

      {:ok, _other} ->
        :malformed

      :error ->
        :unknown
    end
  end

  def entry(_sources, _name), do: :unknown

  defp source?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :describe, 2) and
      function_exported?(module, :fetch, 2)
  end
end
