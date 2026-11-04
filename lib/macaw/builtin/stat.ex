defmodule Macaw.Builtin.Stat do
  @moduledoc """
  The built-in stat (spec/05 §6.3), `"macaw.stat"`: one number from a slot's rows, with its
  label and unit, of kind `:content`, `:pure`.

    * **parameters:** `label` (text, `""`, the field's label from the schema when empty);
      `reduce` (`Macaw.Builtin.Reading.reduces/0`, `"latest"`, bindable); `digits` (`""`, or
      `"0"` to `"6"` decimal places; `""` for the number as it is);
    * **declarations:** one slot, `rows`, with roles `value` (a `:number`) and `t` (the window
      field, optional, which `latest` and `delta` read by); reading load `:glance`;
    * **order and budget:** `latest` and `delta` ask for the rows newest first, `latest` for
      one row;
    * **markup:** the label as a heading, then the number in a `<data>` with its unit's
      symbol. A slot with no readings shows an en dash, never zero. `latest` or `delta` with
      no time field draws `invalid`;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.stat", kinds: [:content]

  alias Macaw.Builtin.{Reading, Text}
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.Delivery

  @impl true
  def parameters do
    %{
      "label" => %{type: :text, default: "", doc: "the heading; the field's label when empty"},
      "reduce" => %{
        type: :category,
        values: Reading.reduces(),
        default: "latest",
        bindable: true,
        doc: "the statistic of the value role's readings"
      },
      "digits" => %{
        type: :category,
        values: ["", "0", "1", "2", "3", "4", "5", "6"],
        default: "",
        doc: "decimal places; empty for the number as it is"
      }
    }
  end

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         doc: "the rows to read",
         requires: %{
           "value" => %{type: :number, doc: "the field read"},
           "t" => %{
             type: :time,
             window: true,
             optional: true,
             doc: "when; latest and delta read by it"
           }
         }
       }
     },
     reading: :glance}
  end

  @impl true
  def order("rows", %{"reduce" => reduce}), do: Reading.order(reduce)

  @impl true
  def budget("rows", %{"reduce" => reduce}, _size), do: Reading.budget(reduce)

  @doc """
  The stat's one static stylesheet, every color a theme custom property with the default
  theme's value as its fallback. It loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-stat{font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333)}
    .mw-stat-label{margin:0;font-size:0.875rem;font-weight:600}
    .mw-stat-value{margin:0;font-size:2rem;line-height:1.2}
    .mw-stat-unit{margin-inline-start:0.25em;font-size:1rem;color:var(--mw-neutral,#6f7480)}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # A capped or stale number is still a number: the notice, then the stat.
  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{}}} = assigns)
      when drawn in [:capped, :stale] do
    {:safe,
     [
       Drawn.render(drawn, assigns.context) |> Phoenix.HTML.Safe.to_iodata(),
       render(:content, %{assigns | drawn: :live}) |> Phoenix.HTML.Safe.to_iodata()
     ]}
  end

  def render(:content, %{drawn: :live, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns) do
    case Reading.value(delivery, assigns.context, assigns.settings["reduce"]) do
      {:ok, number} -> render_stat(number, assigns)
      :needs_time -> Drawn.render(:invalid, assigns.context)
      :no_rows -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  defp render_stat(number, %{context: context, settings: settings}) do
    field = Context.field(context, "rows", "value") || "value"
    heading = Context.heading(context, 0)

    label =
      if settings["label"] == "",
        do: Context.label(context, "rows", field),
        else: settings["label"]

    {:safe,
     [
       ~s(<div class="mw-stat"><),
       heading,
       ~s( class="mw-stat-label">),
       escape(label),
       "</",
       heading,
       ~s(><p class="mw-stat-value">),
       shown(number, settings["digits"]),
       unit(Text.unit(context, "rows", field), number, settings["reduce"]),
       "</p></div>"
     ]}
  end

  defp shown(nil, _digits), do: "–"

  defp shown(number, digits) do
    [
      ~s(<data value="),
      to_string(number),
      ~s(">),
      Reading.format(number, places(digits)),
      "</data>"
    ]
  end

  # A count counts rows, in no unit; nothing has no unit to show.
  defp unit(_unit, nil, _reduce), do: []
  defp unit(_unit, _number, "count"), do: []
  defp unit(nil, _number, _reduce), do: []

  defp unit(unit, _number, _reduce),
    do: [~s(<span class="mw-stat-unit">), escape(unit), "</span>"]

  defp places(""), do: nil
  defp places(digits), do: String.to_integer(digits)

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
