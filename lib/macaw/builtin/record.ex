defmodule Macaw.Builtin.Record do
  @moduledoc """
  The built-in record (spec/05 §6.5), `"macaw.record"`: one row as a definition list, of
  kind `:content`, `:pure`.

    * **parameters:** `label` (text, `""`), its heading, none when empty; `identity` (text,
      `""`, bindable), the row whose identity field has this value; `pick` (`"first"` or
      `"last"`, `"first"`), the row in time order when `identity` is empty;
    * **declarations:** one slot, `rows`, with roles `fields` (the fields shown, in order, any
      type, many, optional; every column when unbound) and `t` (the window field, optional,
      which `pick` reads by); reading load `:scan`;
    * **order and budget:** picking asks for one row, first or last by `t`; an `identity` asks
      for every row up to the ceiling, in no order;
    * **markup:** the label as a heading, then a `<dl>`, each term the field's label and unit
      (`Macaw.Builtin.Text.heading/3`), each value as the table writes it, `nil` empty. No
      matching row draws `no_data`. `last` with no time field, or an `identity` with no single
      identity field, draws `invalid`;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.record", kinds: [:content]

  alias Macaw.Builtin.Text
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Schema, Table}

  @impl true
  def parameters do
    %{
      "label" => %{type: :text, default: "", doc: "the heading; none when empty"},
      "identity" => %{
        type: :text,
        default: "",
        bindable: true,
        doc: "the row whose identity field has this value; empty to pick by time"
      },
      "pick" => %{
        type: :category,
        values: ["first", "last"],
        default: "first",
        doc: "the row in time order, when identity is empty"
      }
    }
  end

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         doc: "the rows to choose from",
         requires: %{
           "fields" => %{
             type: [:time, :number, :category, :text, :color, :point],
             many: true,
             optional: true,
             doc: "the fields shown, in order; every column when unbound"
           },
           "t" => %{type: :time, window: true, optional: true, doc: "when; pick reads by it"}
         }
       }
     },
     reading: :scan}
  end

  @impl true
  def order("rows", %{"identity" => "", "pick" => "last"}), do: [{{:role, "t"}, :desc}]
  def order("rows", %{"identity" => "", "pick" => "first"}), do: [{{:role, "t"}, :asc}]
  def order("rows", _settings), do: []

  @impl true
  def budget("rows", %{"identity" => ""}, _size), do: 1
  def budget("rows", _settings, _size), do: nil

  @doc """
  The record's one static stylesheet, every color a theme custom property with the default
  theme's value as its fallback. It loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-record{font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333)}
    .mw-record-label{margin:0 0 0.5rem;font-size:1rem;font-weight:600}
    .mw-record dl{display:grid;grid-template-columns:minmax(6rem,max-content) 1fr;gap:0.25rem 1rem;margin:0}
    .mw-record dt{font-weight:600;color:var(--mw-neutral,#6f7480)}
    .mw-record dd{margin:0}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # Picking asks for one row, so its delivery is always reduced and its cell capped; a row
  # that is the one asked for is the whole answer, and draws no notice (spec/05 §6.5). A row
  # looked up by identity may have been past the cap, so it keeps it.
  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns)
      when drawn in [:capped, :stale] do
    body = render(:content, %{assigns | drawn: :live})

    if whole?(drawn, delivery, assigns.settings) do
      body
    else
      {:safe,
       [
         Phoenix.HTML.Safe.to_iodata(Drawn.render(drawn, assigns.context)),
         Phoenix.HTML.Safe.to_iodata(body)
       ]}
    end
  end

  def render(:content, %{drawn: :live, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns) do
    with {:ok, table} <- Delivery.table(delivery),
         {:ok, rows} <- Table.rows(table) do
      case chosen(rows, assigns.settings, assigns.context) do
        {:ok, row} -> render_record(row, Table.names(table), assigns)
        :none -> Drawn.render(:no_data, assigns.context)
        :invalid -> Drawn.render(:invalid, assigns.context)
      end
    else
      {:error, _faults} -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  defp whole?(:capped, %Delivery{served: served}, %{"identity" => ""}),
    do: not served.capped and served.ordered != :sample

  defp whole?(_drawn, _delivery, _settings), do: false

  # By identity; else the row the order put first, which `last` needs a time field for.
  defp chosen(rows, %{"identity" => ""} = settings, context) do
    cond do
      settings["pick"] == "last" and Context.field(context, "rows", "t") == nil -> :invalid
      rows == [] -> :none
      true -> {:ok, hd(rows)}
    end
  end

  defp chosen(rows, %{"identity" => identity}, context) do
    case identity_field(context) do
      nil ->
        :invalid

      field ->
        case Enum.find(rows, &(Text.value(Map.get(&1, field)) == identity)) do
          nil -> :none
          row -> {:ok, row}
        end
    end
  end

  # A composite identity has no one value to look up by.
  defp identity_field(context) do
    with %Schema{} = schema <- Map.get(context.schemas, "rows"),
         [field] <- Schema.identity(schema) do
      to_string(field)
    else
      _none -> nil
    end
  end

  defp render_record(row, names, %{context: context, settings: settings}) do
    fields = Context.field(context, "rows", "fields") || names
    heading = Context.heading(context, 0)

    {:safe,
     [
       ~s(<div class="mw-record">),
       if(settings["label"] != "",
         do: [
           "<",
           heading,
           ~s( class="mw-record-label">),
           escape(settings["label"]),
           "</",
           heading,
           ">"
         ],
         else: []
       ),
       "<dl>",
       Enum.map(fields, fn field ->
         [
           "<dt>",
           escape(Text.heading(context, "rows", field)),
           "</dt><dd>",
           escape(Text.value(Map.get(row, field))),
           "</dd>"
         ]
       end),
       "</dl></div>"
     ]}
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
