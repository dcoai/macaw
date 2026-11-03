defmodule Macaw.Builtin.StatusGrid do
  @moduledoc """
  The built-in status grid (spec/05 §6.2), `"macaw.status_grid"`: one tile per thing,
  each showing its state, of kind `:content`, `:pure`.

    * **parameters:** `label` (text, `""`), the grid's heading, none when empty;
    * **declarations:** one slot, `rows`, with roles `name` (the identity field, any of the
      types an identity takes), `status` (a `:category`) and `detail` (optional, any
      type); reading load `:glance`;
    * **markup:** a list of tiles in the order of the `name` field's values (by its type,
      as a source orders), each with the name, the state's words and the detail. A tile's
      class is `mw-status-<role>`: the role the `status` field's schema gives its state
      (`:good`, `:warning`, `:bad`, `:info`, `:neutral` or a theme's own word), `neutral`
      for a state with none. Color is never the only cue: the state's words are always
      shown. A capped or stale grid draws its notice above its tiles;
    * **stylesheet:** `stylesheet/0`, served at `stylesheet_path/0`, its content address.
  """

  use Macaw.Component, name: "macaw.status_grid", kinds: [:content]

  alias Macaw.Builtin.Text
  alias Macaw.Component.{Context, Drawn}
  alias Macaw.Data.{Delivery, Schema, Table}
  alias Macaw.Data.Source.Order

  # A role becomes a class only when it spells one; any other word is drawn neutral.
  @role ~r/\A[a-z][a-z0-9_-]*\z/
  @roles ~w(good warning bad info neutral)

  @impl true
  def parameters do
    %{"label" => %{type: :text, default: "", doc: "the grid's heading; none when empty"}}
  end

  @impl true
  def declarations(_settings) do
    {:ok,
     slots: %{
       "rows" => %{
         doc: "one row per thing",
         requires: %{
           "name" => %{
             type: [:category, :text, :number],
             identity: true,
             doc: "what each tile is about"
           },
           "status" => %{type: :category, doc: "its state; the schema's status gives its role"},
           "detail" => %{
             type: [:time, :number, :category, :text],
             optional: true,
             doc: "a line under the state"
           }
         }
       }
     },
     reading: :glance}
  end

  @doc """
  The grid's one static stylesheet: the list, its tiles, and a rule per built-in status
  role, every color a theme custom property with the default theme's value as its
  fallback. It loads and imports nothing.
  """
  @spec stylesheet() :: String.t()
  def stylesheet do
    """
    .mw-status-grid{font-family:var(--mw-font-family,sans-serif);color:var(--mw-text,#333333)}
    .mw-status-grid ul{display:grid;grid-template-columns:repeat(auto-fill,minmax(10rem,1fr));gap:0.5rem;list-style:none;margin:0;padding:0}
    .mw-status-tile{padding:0.5rem 0.75rem;background-color:var(--mw-surface,#eef2f6);border-inline-start:0.375rem solid var(--mw-neutral,#6f7480)}
    .mw-status-name{font-weight:600}
    .mw-status-state,.mw-status-detail{margin:0}
    .mw-status-good{border-inline-start-color:var(--mw-good,#4ca34b)}
    .mw-status-warning{border-inline-start-color:var(--mw-warning,#bd7407)}
    .mw-status-bad{border-inline-start-color:var(--mw-bad,#c23238)}
    .mw-status-info{border-inline-start-color:var(--mw-info,#3b6fa8)}
    .mw-status-neutral{border-inline-start-color:var(--mw-neutral,#6f7480)}
    """
  end

  @doc "The stylesheet's path, its content address (`Macaw.Component.Stylesheet.path/1`)."
  @spec stylesheet_path() :: String.t()
  def stylesheet_path, do: Macaw.Component.Stylesheet.path(stylesheet())

  @doc "The status roles the stylesheet colors; any other role is drawn as `neutral`'s."
  @spec roles() :: [String.t()]
  def roles, do: @roles

  # Capped and stale rows are still rows: the notice, then the tiles.
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
    with {:ok, table} <- Delivery.table(delivery),
         rows when rows != [] <- Table.rows(table) do
      render_grid(rows, assigns)
    else
      _no_rows -> Drawn.render(:no_data, assigns.context)
    end
  end

  def render(:content, %{drawn: :live, context: context}), do: Drawn.render(:no_data, context)
  def render(:content, %{drawn: drawn, context: context}), do: Drawn.render(drawn, context)

  # On a surface the required roles are always bound (validation refuses a cell without
  # them); rendered alone, as the kit does, a role reads the column of its own name.
  defp render_grid(rows, %{context: context, settings: settings}) do
    name = Context.field(context, "rows", "name") || "name"
    status = Context.field(context, "rows", "status") || "status"
    detail = Context.field(context, "rows", "detail")
    schema = Map.get(context.schemas, "rows")
    heading = Context.heading(context, 0)

    {:safe,
     [
       ~s(<div class="mw-status-grid">),
       if(settings["label"] != "",
         do: ["<", heading, ">", escape(settings["label"]), "</", heading, ">"],
         else: []
       ),
       "<ul>",
       rows
       |> ordered(name, schema)
       |> Enum.map(&tile(&1, name, status, detail, schema, context)),
       "</ul></div>"
     ]}
  end

  # The tiles in the name field's order, compared by its type as a source orders; with no
  # schema to order by, as delivered.
  defp ordered(rows, _name, nil), do: rows

  defp ordered(rows, name, %Schema{} = schema) do
    case Order.sort(rows, [{name, :asc}], schema) do
      {:ok, sorted} -> sorted
      {:error, _faults} -> rows
    end
  end

  defp tile(row, name, status, detail, schema, context) do
    thing = text(Map.get(row, name))
    state = Map.get(row, status)

    [
      ~s(<li class="mw-status-tile mw-status-),
      role(schema, status, state),
      ~s(" id="),
      Context.id(context, "s-" <> Base.url_encode64(thing, padding: false)),
      ~s("><p class="mw-status-name">),
      escape(thing),
      ~s(</p><p class="mw-status-state">),
      escape(words(schema, status, state)),
      "</p>",
      detail(row, detail, context),
      "</li>"
    ]
  end

  defp detail(_row, nil, _context), do: []

  defp detail(row, field, context) do
    case Map.get(row, field) do
      nil ->
        []

      value ->
        unit = Text.unit(context, "rows", field)
        shown = if unit, do: "#{text(value)} #{unit}", else: text(value)
        [~s(<p class="mw-status-detail">), escape(shown), "</p>"]
    end
  end

  # The state's role from the status field's schema, `neutral` without one or for a word
  # that spells no class.
  defp role(%Schema{} = schema, field, state) when state != nil do
    with {:ok, roles} <- Schema.fetch(schema, field, :status),
         role when is_binary(role) <- Map.get(roles, text(state)),
         true <- Regex.match?(@role, role) do
      role
    else
      _none -> "neutral"
    end
  end

  defp role(_schema, _field, _state), do: "neutral"

  # The state's words: its value's display name from the schema, else its spelling, and
  # an en dash for no state, so a tile never relies on its color alone.
  defp words(_schema, _field, nil), do: "–"

  defp words(%Schema{} = schema, field, state) do
    Map.get(Schema.value_names(schema, field), text(state), text(state))
  end

  defp words(nil, _field, state), do: text(state)

  defp text(nil), do: ""
  defp text(%DateTime{} = t), do: DateTime.to_iso8601(t)
  defp text(value) when is_binary(value), do: value
  defp text(value), do: to_string(value)

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
