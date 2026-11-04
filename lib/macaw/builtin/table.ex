defmodule Macaw.Builtin.Table do
  @moduledoc """
  The built-in table (spec/05 §6.1), `"macaw.table"`: an HTML `<table>` of whole rows, of
  kind `:content`, `:pure`.

    * **parameters:** `caption` (text, `"Table"`); `identity` (text, `""`), the field naming
      each row, `""` for rows that can't be selected; `sort` (text, `""`, bindable), the
      field rows are sorted by; `order` (`"asc"` or `"desc"`, bindable);
    * **declarations:** one slot, `rows`, whose optional `columns` role names the fields
      shown, in order (any type, many), when unbound every column in the delivered table's
      order (`Macaw.Data.Table.names/1`: name order for rows given as maps);
      events `"sort"` and `"select"`; it writes
      `selection` as an identity; it observes `:activate` and `:select`; reading load
      `:scan`;
    * **budget:** the rows its declared height shows at 32 px a row, times four, at least 10;
    * **markup:** a capped or stale table draws its notice above its rows; a caption, a header of scoped `<th>` each holding a real button that emits
      `sort`, the sorted column's `aria-sort`, a row per delivered row sorted when `sort`
      names a column (nil last, ties in delivered order), and with an `identity` field a
      `select` button in each row's first cell and the row's id from its identity;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.table", kinds: [:content]

  alias Macaw.Builtin.Text
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Table}

  @impl true
  def parameters do
    %{
      "caption" => %{type: :text, default: "Table", doc: "the table's name"},
      "identity" => %{type: :text, default: "", doc: "the field naming each row; empty for none"},
      "sort" => %{type: :text, default: "", bindable: true, doc: "the field rows are sorted by"},
      "order" => %{type: :category, values: ["asc", "desc"], default: "asc", bindable: true}
    }
  end

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         doc: "the rows, whole",
         requires: %{
           "columns" => %{
             type: [:time, :number, :category, :text, :color, :point],
             many: true,
             optional: true,
             doc: "the fields shown, in order; every column when unbound"
           }
         }
       }
     },
     events: ["sort", "select"],
     writes: %{"selection" => :identity},
     observes: [:activate, :select],
     reading: :scan}
  end

  @impl true
  def budget("rows", _settings, {_w, h}), do: max(10, trunc(h / 32) * 4)

  @doc """
  The table's one static stylesheet: the table, its caption, cells, header and select
  buttons and the sorted column's mark, every color a theme custom property with the
  default theme's value as its fallback. It loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-table{border-collapse:collapse;inline-size:100%;font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333);background-color:var(--mw-background,#ffffff)}
    .mw-table caption{caption-side:top;text-align:start;font-weight:600;padding-block:0.25rem 0.5rem}
    .mw-table th,.mw-table td{text-align:start;padding:0.375rem 0.75rem;border-block-end:1px solid var(--mw-grid,#e0e0e0)}
    .mw-table th{border-block-end-color:var(--mw-axis,#666666)}
    .mw-table tbody tr:nth-child(even){background-color:var(--mw-surface,#eef2f6)}
    .mw-table button{font:inherit;color:inherit;background-color:transparent;border:0;padding:0;cursor:pointer}
    .mw-table th button{font-weight:600}
    .mw-table th[aria-sort] button::after{margin-inline-start:0.25em}
    .mw-table th[aria-sort="ascending"] button::after{content:"\\25B2"}
    .mw-table th[aria-sort="descending"] button::after{content:"\\25BC"}
    .mw-table td button{text-decoration:underline;color:var(--mw-info,#3b6fa8)}
    .mw-table button:focus-visible{outline:2px solid var(--mw-info,#3b6fa8);outline-offset:2px}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # Capped and stale rows are still rows: the notice, then the table.
  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{}}} = assigns)
      when drawn in [:capped, :stale] do
    {:safe,
     [
       Drawn.render(drawn, assigns.context) |> Phoenix.HTML.Safe.to_iodata(),
       render(:content, %{assigns | drawn: :live}) |> Phoenix.HTML.Safe.to_iodata()
     ]}
  end

  # The rows packed into a table for their columns (macaw_data 0.6.0 keeps a delivery's
  # rows as the source gave them); rows that don't pack draw as no data.
  def render(:content, %{drawn: :live, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns) do
    with {:ok, table} <- Delivery.table(delivery),
         {:ok, rows} <- Table.rows(table) do
      render_table(table, rows, assigns)
    else
      {:error, _faults} -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  defp render_table(table, rows, assigns) do
    settings = assigns.settings
    names = Table.names(table)
    # The bound columns, checked against the schema at validation; unbound, every column.
    columns = Context.field(assigns.context, "rows", "columns") || names
    sort = if settings["sort"] in names, do: settings["sort"]
    identity = if settings["identity"] in names, do: settings["identity"]
    rows = sorted(rows, sort, settings["order"])

    {:safe,
     [
       ~s(<table class="mw-table"><caption>),
       escape(settings["caption"]),
       "</caption><thead><tr>",
       Enum.map(columns, &header(&1, sort, settings["order"], assigns.context)),
       "</tr></thead><tbody>",
       Enum.map(rows, &row(&1, columns, identity, assigns.context)),
       "</tbody></table>"
     ]}
  end

  # A column's header reads its field's label, its unit's display symbol after it, from the
  # source's schema (`Macaw.Builtin.Text.heading/3`); the sort button's value stays the field.
  defp header(column, sort, order, context) do
    aria =
      cond do
        column != sort -> ""
        order == "desc" -> ~s( aria-sort="descending")
        true -> ~s( aria-sort="ascending")
      end

    [
      ~s(<th scope="col"#{aria}><button type="button" data-mw-event="sort" value="),
      escape(column),
      ~s(">),
      escape(Text.heading(context, "rows", column)),
      "</button></th>"
    ]
  end

  defp row(row, columns, identity, context) do
    {id, select} =
      case identity && Map.get(row, identity) do
        value when value != nil and value != false ->
          spelled = text(value)

          {~s( id="#{Context.id(context, "r-" <> Base.url_encode64(spelled, padding: false))}"),
           [
             ~s(<button type="button" data-mw-event="select" value="),
             escape(spelled),
             ~s(">Select ),
             escape(spelled),
             "</button> "
           ]}

        _ ->
          {"", []}
      end

    [
      "<tr#{id}>",
      columns
      |> Enum.with_index()
      |> Enum.map(fn {column, i} ->
        ["<td>", if(i == 0, do: select, else: []), escape(text(Map.get(row, column))), "</td>"]
      end),
      "</tr>"
    ]
  end

  # The order the rows slot asks its source for (spec/05 §6.1): the sort column in the
  # sort direction, so a delivery capped at the budget holds the first rows in it.
  @impl true
  def order("rows", %{"sort" => sort, "order" => direction}) when sort != "",
    do: [{sort, if(direction == "desc", do: :desc, else: :asc)}]

  def order(_slot, _settings), do: []

  # Sorted by a column, nil last, ties in delivered order; descending keeps nil last too.
  defp sorted(rows, nil, _order), do: rows

  defp sorted(rows, column, order) do
    {present, missing} = Enum.split_with(rows, &(Map.get(&1, column) != nil))
    direction = if order == "desc", do: :desc, else: :asc
    Enum.sort_by(present, &key(Map.get(&1, column)), direction) ++ missing
  end

  defp key(%DateTime{} = t), do: DateTime.to_unix(t, :microsecond)
  defp key(%NaiveDateTime{} = t), do: NaiveDateTime.to_gregorian_seconds(t)
  defp key(%Date{} = d), do: Date.to_gregorian_days(d)
  defp key(value), do: value

  defp text(nil), do: ""

  defp text(%DateTime{microsecond: {0, _}} = t),
    do: t |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp text(%DateTime{} = t), do: DateTime.to_iso8601(t)
  defp text(%NaiveDateTime{} = t), do: NaiveDateTime.to_iso8601(t)
  defp text(%Date{} = d), do: Date.to_iso8601(d)
  defp text({lon, lat}), do: "#{lon}, #{lat}"
  defp text(value) when is_binary(value), do: value
  defp text(value), do: to_string(value)

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
