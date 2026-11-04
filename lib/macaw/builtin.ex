defmodule Macaw.Builtin do
  @moduledoc """
  The core's built-in components, a package like any other (spec/05 §6): a host enables
  it by listing it, `Macaw.Registry.new!([Macaw.Builtin, …])`, and it is never enabled
  implicitly.

    * `Macaw.Builtin.Table`, `"macaw.table"`: an HTML table of whole rows.
    * `Macaw.Builtin.StatusGrid`, `"macaw.status_grid"`: one tile per thing, showing its state.
    * `Macaw.Builtin.Stat`, `"macaw.stat"`: one number from a slot's rows.
    * `Macaw.Builtin.Meter`, `"macaw.meter"`: one number against its range.
  """

  @doc "The package's members."
  @spec __members__() :: [module()]
  def __members__,
    do: [Macaw.Builtin.Table, Macaw.Builtin.StatusGrid, Macaw.Builtin.Stat, Macaw.Builtin.Meter]
end
