defmodule Macaw.Surface.Words do
  @moduledoc false
  # The surface document's closed vocabularies (spec/06 §3.1): the keys its JSON form reads
  # as atoms, and the atoms a `$atom` may spell. Names (cells, slots, roles, settings and
  # params) are strings in name maps (`Macaw.Surface.name_map?/1`), never keys, so a name
  # never collides with the document's own keys.

  alias Macaw.Layers.Vocabulary

  @keys [
    :surface,
    :name,
    :title,
    :layout,
    :cells,
    :component,
    :kind,
    :settings,
    :slots,
    :source,
    :fields,
    :params,
    :place,
    :x,
    :y,
    :w,
    :h
  ]

  @atoms [:grid, :navigation, :content, :control, :container]

  @key_table Vocabulary.table(@keys)
  @atom_table Vocabulary.table(@atoms)

  @doc false
  @spec keys() :: Vocabulary.table()
  def keys, do: @key_table

  @doc false
  @spec atoms() :: Vocabulary.table()
  def atoms, do: @atom_table
end

defmodule Macaw.Surface.Tags do
  @moduledoc false
  # The surface document's tag table (spec/01 §6 of macaw_layers): a point, and the colors'.
  use Macaw.Layers.Tags, live: ["$point" | Macaw.Layers.Color.Form.tags()]
end
