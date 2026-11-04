defmodule Macaw.Builtin.Meter do
  @moduledoc """
  The built-in meter (spec/05 §6.4), `"macaw.meter"`: one number against its range, in a
  native `<meter>`, of kind `:content`, `:pure`.

    * **parameters:** `label` (text, `""`, the field's label from the schema when empty);
      `reduce` (`Macaw.Builtin.Reading.reduces/0`, `"latest"`, bindable); `min` (`0`); `max`
      (required), above `min` or a fault at its name;
    * **declarations:** one slot, `rows`, with roles `value` (a `:number`) and `t` (the window
      field, optional, which `latest` and `delta` read by); reading load `:glance`;
    * **order and budget:** as the stat's;
    * **markup:** the label as a heading, naming a `<meter>` through `aria-labelledby`, and the
      value with its unit's symbol beside it, so neither color nor length is the only cue.
      `<meter>` clamps its bar to the range; the text shows the true value. A slot with no
      readings shows an en dash and no bar, never zero;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.meter", kinds: [:content]

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
      "min" => %{type: :number, default: 0, doc: "the range's start"},
      "max" => %{type: :number, doc: "the range's end"}
    }
  end

  @impl true
  def declarations(%{"min" => min, "max" => max}) when min >= max,
    do: {:error, [{["max"], {:not_above, min, max}}]}

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
  The meter's one static stylesheet, every color a theme custom property with the default
  theme's value as its fallback. It loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-meter{font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333)}
    .mw-meter-label{margin:0;font-size:0.875rem;font-weight:600}
    .mw-meter meter{display:block;inline-size:100%;block-size:1rem}
    .mw-meter-value{margin:0}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # A capped or stale number is still a number: the notice, then the meter.
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
      {:ok, number} -> render_meter(number, assigns)
      :needs_time -> Drawn.render(:invalid, assigns.context)
      :no_rows -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  defp render_meter(number, %{context: context, settings: settings}) do
    field = Context.field(context, "rows", "value") || "value"
    heading = Context.heading(context, 0)
    id = Context.id(context, "label")

    label =
      if settings["label"] == "",
        do: Context.label(context, "rows", field),
        else: settings["label"]

    {:safe,
     [
       ~s(<div class="mw-meter"><),
       heading,
       ~s( class="mw-meter-label" id="),
       id,
       ~s(">),
       escape(label),
       "</",
       heading,
       ">",
       bar(number, id, settings),
       ~s(<p class="mw-meter-value">),
       words(number, Text.unit(context, "rows", field)),
       "</p></div>"
     ]}
  end

  defp bar(nil, _id, _settings), do: []

  defp bar(number, id, settings) do
    [
      ~s(<meter aria-labelledby="),
      id,
      ~s(" value="),
      to_string(number),
      ~s(" min="),
      to_string(settings["min"]),
      ~s(" max="),
      to_string(settings["max"]),
      ~s(">),
      Reading.format(number, nil),
      "</meter>"
    ]
  end

  defp words(nil, _unit), do: "–"
  defp words(number, nil), do: Reading.format(number, nil)
  defp words(number, unit), do: escape("#{Reading.format(number, nil)} #{unit}")

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
