defmodule Macaw.Builtin.Text do
  @moduledoc """
  The words the built-in components head a field's value with (spec/05 §6): its label
  from the source's schema, and its unit as a reader writes it.

  A schema posts a unit as its UCUM code (`Cel`, `[mi_i]/h`, `{request}/s`), the machine's
  spelling, chosen so units convert exactly. A reader sees its display symbol, with its
  annotations (`°C`, `mi/h`, `request/s`): `Macaw.Data.Unit.symbol/2` with
  `annotations: true`, since without them `{request}/s` would read `/s` and say less
  than the code. A code with no symbol is shown as it is.
  """

  alias Macaw.Component.Context
  alias Macaw.Data.{Schema, Unit}

  # A role becomes a class only when it spells one; any other word is drawn neutral.
  @role ~r/\A[a-z][a-z0-9_-]*\z/

  @doc """
  The unit `field` of `slot` is shown in: its code's display symbol, the code itself when
  it has none, or `nil` for a field without a unit.
  """
  @spec unit(Context.t(), String.t(), String.t()) :: String.t() | nil
  def unit(%Context{} = context, slot, field) do
    case Context.unit(context, slot, field) do
      nil -> nil
      code -> symbol(code)
    end
  end

  @doc """
  The display symbol of a UCUM `code`, annotations kept, or the code itself when
  `Macaw.Data.Unit.symbol/2` gives none.
  """
  @spec symbol(String.t()) :: String.t()
  def symbol(code) when is_binary(code) do
    case Unit.symbol(code, annotations: true) do
      {:ok, symbol} -> symbol
      {:error, _reason} -> code
    end
  end

  @doc """
  The role `field`'s schema gives a state (macaw_data spec/01 §1.6): a theme's word, `neutral`
  for a state with none, for no state, for no schema, and for a word that spells no class. A
  theme's own word is kept, as a class it may style.
  """
  @spec role(Schema.t() | nil, String.t(), term()) :: String.t()
  def role(%Schema{} = schema, field, state) when state != nil do
    with {:ok, roles} <- Schema.fetch(schema, field, :status),
         role when is_binary(role) <- Map.get(roles, value(state)),
         true <- Regex.match?(@role, role) do
      role
    else
      _none -> "neutral"
    end
  end

  def role(_schema, _field, _state), do: "neutral"

  @doc """
  A state's words, so color is never the only cue: its display name from the schema, else
  its spelling, and an en dash for no state.
  """
  @spec words(Schema.t() | nil, String.t(), term()) :: String.t()
  def words(_schema, _field, nil), do: "–"

  def words(%Schema{} = schema, field, state),
    do: Map.get(Schema.value_names(schema, field), value(state), value(state))

  def words(nil, _field, state), do: value(state)

  @doc """
  A value as a built-in component writes it: a time as ISO 8601, whole seconds without a
  fraction; a point as `lon, lat`; `nil` as nothing.
  """
  @spec value(term()) :: String.t()
  def value(nil), do: ""

  def value(%DateTime{microsecond: {0, _}} = t),
    do: t |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  def value(%DateTime{} = t), do: DateTime.to_iso8601(t)
  def value(%NaiveDateTime{} = t), do: NaiveDateTime.to_iso8601(t)
  def value(%Date{} = d), do: Date.to_iso8601(d)
  def value({lon, lat}), do: "#{lon}, #{lat}"
  def value(value) when is_binary(value), do: value
  def value(value), do: to_string(value)

  @doc """
  The heading of `field` of `slot`: its label (`Macaw.Component.Context.label/3`, the
  field's name without one), then its unit in parentheses when it has one:
  `Request rate (request/s)`.
  """
  @spec heading(Context.t(), String.t(), String.t()) :: String.t()
  def heading(%Context{} = context, slot, field) do
    label = Context.label(context, slot, field)

    case unit(context, slot, field) do
      nil -> label
      unit -> "#{label} (#{unit})"
    end
  end
end
