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
  alias Macaw.Data.Unit

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
