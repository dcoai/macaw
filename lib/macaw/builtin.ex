defmodule Macaw.Builtin do
  @moduledoc """
  The core's built-in components, a package like any other (spec/05 §6): a host enables
  it by listing it, `Macaw.Registry.new!([Macaw.Builtin, …])`, and it is never enabled
  implicitly.

    * `Macaw.Builtin.Table`, `"macaw.table"`: an HTML table of whole rows.
  """

  @doc "The package's members."
  @spec __members__() :: [module()]
  def __members__, do: [Macaw.Builtin.Table]
end
