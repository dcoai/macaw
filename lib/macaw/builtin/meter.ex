defmodule Macaw.Builtin.Meter do
  @moduledoc """
  The built-in meter (spec/05 §6.4), `"macaw.meter"`: one number against its range, in a
  native `<meter>`, of kind `:content`, `:pure`.

    * **parameters:** `label` (text, `""`, the field's label from the schema when empty);
      `reduce` (`Macaw.Builtin.Reading.reduces/0`, `"latest"`, bindable); `min` (`0`); `max`
      (required), above `min` or a fault at its name; `low`, `high` and `optimum` (optional
      numbers, not bindable), each in the range and `low` not above `high`, or a fault at
      its name;
    * **declarations:** one slot, `rows`, with roles `value` (a `:number`) and `t` (the window
      field, optional, which `latest` and `delta` read by); reading load `:glance`;
    * **order and budget:** as the stat's;
    * **markup:** the label as a heading, naming a `<meter>` through `aria-labelledby`, and the
      value with its unit's symbol beside it, and the word `low` or `high` when it's past
      that threshold, so neither color nor length is the only cue. `<meter>` clamps its bar
      to the range; the text shows the true value. A slot with no readings shows an en dash
      and no bar, never zero;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.meter", kinds: [:content]

  alias Macaw.Builtin.{Reading, Text}
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.Delivery

  @thresholds ~w(low high optimum)

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
      "max" => %{type: :number, doc: "the range's end"},
      "low" => %{type: :number, default: nil, doc: "below this, the value is in the low band"},
      "high" => %{type: :number, default: nil, doc: "above this, the value is in the high band"},
      "optimum" => %{type: :number, default: nil, doc: "the best value, which band is good"}
    }
  end

  @impl true
  def declarations(%{"min" => min, "max" => max}) when min >= max,
    do: {:error, [{["max"], {:not_above, min, max}}]}

  def declarations(settings) do
    case thresholds(settings) do
      [] ->
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

      faults ->
        {:error, faults}
    end
  end

  # Every threshold given is in the range, and low isn't above high. nil is no value, and is
  # never judged. The browser would clamp each of these, hiding the mistake.
  defp thresholds(%{"min" => min, "max" => max} = settings) do
    outside =
      for name <- @thresholds,
          value = settings[name],
          value != nil,
          value < min or value > max,
          do: {[name], {:outside_range, value, min, max}}

    outside ++ crossed(settings["low"], settings["high"])
  end

  defp thresholds(_settings), do: []

  defp crossed(low, high) when is_number(low) and is_number(high) and low > high,
    do: [{["high"], {:below_low, low, high}}]

  defp crossed(_low, _high), do: []

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
    .mw-meter-band{margin-inline-start:0.25em;color:var(--mw-neutral,#6f7480)}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # A capped or stale number is still a number: the notice, then the meter.
  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns)
      when drawn in [:capped, :stale] do
    body = render(:content, %{assigns | drawn: :live})

    case Reading.notice(drawn, delivery, assigns.context, assigns.settings["reduce"]) do
      nil ->
        body

      notice ->
        {:safe, [Phoenix.HTML.Safe.to_iodata(notice), Phoenix.HTML.Safe.to_iodata(body)]}
    end
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
       band(number, settings),
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
      ~s("),
      for(name <- @thresholds, settings[name] != nil, do: threshold(name, settings[name])),
      ">",
      Reading.format(number, nil),
      "</meter>"
    ]
  end

  # Left out when not given: to_string(nil) would write low="".
  defp threshold(name, value), do: [" ", name, ~s(="), to_string(value), ~s(")]

  # The band in words, as <meter> reads it: on a threshold is in the middle.
  defp band(number, %{"low" => low}) when is_number(number) and is_number(low) and number < low,
    do: ~s( <span class="mw-meter-band">low</span>)

  defp band(number, %{"high" => high})
       when is_number(number) and is_number(high) and number > high,
       do: ~s( <span class="mw-meter-band">high</span>)

  defp band(_number, _settings), do: []

  defp words(nil, _unit), do: "–"
  defp words(number, nil), do: Reading.format(number, nil)
  defp words(number, unit), do: escape("#{Reading.format(number, nil)} #{unit}")

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
