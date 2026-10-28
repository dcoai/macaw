defmodule Macaw.Surface.Words do
  @moduledoc false
  # The surface document's closed vocabularies (spec/06 §3.1): the keys its map form reads
  # as atoms, and the atoms a `$atom` may spell. Names (cells, slots, settings and params)
  # are strings; one that spells a key is written as that key's atom and read back as its
  # spelling, so a name never collides with the document's own keys.

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

  @doc false
  # A name as the map form writes it: the key's atom when it spells one, else the string.
  @spec written(String.t()) :: atom() | String.t()
  def written(name) when is_binary(name) do
    case Vocabulary.fetch(@key_table, name) do
      {:ok, atom} -> atom
      :error -> name
    end
  end

  @doc false
  # Plain data with every map key written as a name, deep.
  @spec write_data(term()) :: term()
  def write_data(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {written(k), write_data(v)} end)

  def write_data(list) when is_list(list), do: Enum.map(list, &write_data/1)
  def write_data(leaf), do: leaf
end

defmodule Macaw.Surface.Tags do
  @moduledoc false
  # The surface document's tag table (spec/01 §6 of macaw_layers): no tags of its own.
  use Macaw.Layers.Tags, live: []
end
