defmodule Macaw.Builtin.Feed do
  @moduledoc """
  The built-in feed (spec/05 §6.6), `"macaw.feed"`: time-ordered rows, newest first, of kind
  `:content`, `:pure`.

    * **parameters:** `label` (text, `""`), its heading, none when empty; `limit` (a positive
      whole number, `20`), the most items shown;
    * **declarations:** one slot, `rows`, with roles `t` (the window field), `title` (`:text` or
      `:category`), `body` (`:text`, optional) and `level` (`:category`, optional), whose
      schema's `status` gives an item's role; reading load `:scan`;
    * **order and budget:** the newest `limit` rows, newest first by `t`;
    * **markup:** an ordered list of items, each a `<time>`, the title, the body, and a level's
      words beside its role's color, so color is never the only cue. The newest `limit` are
      the whole answer, so they draw no capped notice unless the source cut them before they
      were ordered or says it stopped short;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.feed", kinds: [:content]

  alias Macaw.Builtin.Text
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Table}

  @impl true
  def parameters do
    %{
      "label" => %{type: :text, default: "", doc: "the heading; none when empty"},
      "limit" => %{
        type: :number,
        default: 20,
        doc: "the most items shown, a positive whole number"
      }
    }
  end

  @impl true
  def declarations(%{"limit" => limit}) when not is_integer(limit) or limit < 1,
    do: {:error, [{["limit"], {:type, :pos_integer}}]}

  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         doc: "the rows to list",
         requires: %{
           "t" => %{type: :time, window: true, doc: "when"},
           "title" => %{type: [:text, :category], doc: "what happened"},
           "body" => %{type: :text, optional: true, doc: "more about it"},
           "level" => %{
             type: :category,
             optional: true,
             doc: "how much it matters; the schema's status gives its role"
           }
         }
       }
     },
     reading: :scan}
  end

  @impl true
  def order("rows", _settings), do: [{{:role, "t"}, :desc}]

  @impl true
  def budget("rows", %{"limit" => limit}, _size), do: limit

  @doc """
  The feed's one static stylesheet: the list, its items, and a rule per built-in status role,
  every color a theme custom property with the default theme's value as its fallback. It
  loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-feed{font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333)}
    .mw-feed-label{margin:0 0 0.5rem;font-size:1rem;font-weight:600}
    .mw-feed ol{list-style:none;margin:0;padding:0}
    .mw-feed-item{padding:0.375rem 0.75rem;border-inline-start:0.25rem solid var(--mw-grid,#e0e0e0);border-block-end:1px solid var(--mw-grid,#e0e0e0)}
    .mw-feed-item time{font-size:0.875rem;color:var(--mw-neutral,#6f7480)}
    .mw-feed-title,.mw-feed-body,.mw-feed-level{margin:0}
    .mw-feed-title{font-weight:600}
    .mw-feed-level{font-size:0.875rem}
    .mw-feed-good{border-inline-start-color:var(--mw-good,#4ca34b)}
    .mw-feed-warning{border-inline-start-color:var(--mw-warning,#bd7407)}
    .mw-feed-bad{border-inline-start-color:var(--mw-bad,#c23238)}
    .mw-feed-info{border-inline-start-color:var(--mw-info,#3b6fa8)}
    .mw-feed-neutral{border-inline-start-color:var(--mw-neutral,#6f7480)}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  # The newest `limit` are what the feed asked for, so its capped cell is the whole answer
  # unless the source cut its rows before ordering or says it stopped short.
  @impl true
  def render(:content, %{drawn: drawn, deliveries: %{"rows" => %Delivery{} = delivery}} = assigns)
      when drawn in [:capped, :stale] do
    body = render(:content, %{assigns | drawn: :live})

    if drawn == :capped and not delivery.served.capped and delivery.served.ordered != :sample do
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
         {:ok, [_ | _] = rows} <- Table.rows(table) do
      render_feed(rows, assigns)
    else
      _no_rows -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  # On a surface the required roles are always bound (validation refuses a cell without
  # them); rendered alone, as the kit does, a role reads the column of its own name.
  defp render_feed(rows, %{context: context, settings: settings}) do
    fields = %{
      t: Context.field(context, "rows", "t") || "t",
      title: Context.field(context, "rows", "title") || "title",
      body: Context.field(context, "rows", "body"),
      level: Context.field(context, "rows", "level")
    }

    schema = Map.get(context.schemas, "rows")
    heading = Context.heading(context, 0)

    {:safe,
     [
       ~s(<div class="mw-feed">),
       if(settings["label"] != "",
         do: [
           "<",
           heading,
           ~s( class="mw-feed-label">),
           escape(settings["label"]),
           "</",
           heading,
           ">"
         ],
         else: []
       ),
       "<ol>",
       rows |> Enum.take(settings["limit"]) |> Enum.map(&item(&1, fields, schema)),
       "</ol></div>"
     ]}
  end

  defp item(row, fields, schema) do
    time = Text.value(Map.get(row, fields.t))

    [
      ~s(<li class="mw-feed-item),
      level_class(row, fields.level, schema),
      ~s("><time datetime="),
      escape(time),
      ~s(">),
      escape(time),
      ~s(</time><p class="mw-feed-title">),
      escape(Text.value(Map.get(row, fields.title))),
      "</p>",
      level(row, fields.level, schema),
      body(row, fields.body),
      "</li>"
    ]
  end

  defp level_class(_row, nil, _schema), do: []

  defp level_class(row, field, schema),
    do: [" mw-feed-", Text.role(schema, field, Map.get(row, field))]

  defp level(_row, nil, _schema), do: []

  defp level(row, field, schema) do
    [
      ~s(<p class="mw-feed-level">),
      escape(Text.words(schema, field, Map.get(row, field))),
      "</p>"
    ]
  end

  defp body(_row, nil), do: []

  defp body(row, field) do
    case Map.get(row, field) do
      nil -> []
      value -> [~s(<p class="mw-feed-body">), escape(Text.value(value)), "</p>"]
    end
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
