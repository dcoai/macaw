defmodule Macaw.Test.Note do
  @moduledoc false
  # A pure component with no slots: a paragraph of its text setting.
  use Macaw.Component,
    name: "test.note",
    kinds: [:content, :navigation],
    hooks: %{"Note" => "priv/static/note.js"}

  @impl true
  def parameters, do: %{"text" => %{type: :text, default: "Hello"}}

  @impl true
  def render(:navigation, assigns),
    do: {:safe, ~s(<nav aria-label="Notes"><a href="/">#{assigns.settings["text"]}</a></nav>)}

  def render(:content, assigns) do
    case assigns.drawn do
      :live ->
        {:safe,
         [
           "<p>",
           Phoenix.HTML.html_escape(assigns.settings["text"]) |> Phoenix.HTML.safe_to_string(),
           "</p>"
         ]}

      state ->
        Macaw.Component.Drawn.render(state, assigns.context)
    end
  end
end

defmodule Macaw.Test.Other do
  @moduledoc false
  # Another component named as Note is, in another package.
  use Macaw.Component, name: "test.note", kinds: [:content]

  @impl true
  def render(:content, _assigns), do: {:safe, "<p>other</p>"}
end

defmodule Macaw.Test.Hooked do
  @moduledoc false
  # A component whose hook shares Note's name.
  use Macaw.Component,
    name: "test.hooked",
    kinds: [:content],
    hooks: %{"Note" => "priv/static/other.js"}

  @impl true
  def render(:content, _assigns), do: {:safe, "<p>hooked</p>"}
end

defmodule Macaw.Test.Package do
  @moduledoc false
  def __members__, do: [Macaw.Test.Note]
end

defmodule Macaw.Test.OtherPackage do
  @moduledoc false
  def __members__, do: [Macaw.Test.Other]
end

defmodule Macaw.Test.HookedPackage do
  @moduledoc false
  def __members__, do: [Macaw.Test.Hooked]
end

defmodule Macaw.Test.Series do
  @moduledoc false
  # A pure component reading a time series: a window role and a number role.
  use Macaw.Component, name: "test.series", kinds: [:content]

  @impl true
  def parameters, do: %{"label" => %{type: :text, default: "Series"}}

  @impl true
  def declarations(_settings),
    do:
      {:ok,
       slots: %{
         "points" => %{requires: %{"x" => %{type: :time, window: true}, "y" => %{type: :number}}}
       },
       reading: :glance}

  @impl true
  def budget("points", _settings, {w, _h}), do: max(1, trunc(w / 10))

  @impl true
  def render(:content, %{drawn: :live} = assigns) do
    rows = assigns.deliveries |> Map.fetch!("points") |> Macaw.Data.Delivery.rows()
    h = Macaw.Component.Context.heading(assigns.context, 0)
    {:safe, ~s(<#{h}>#{assigns.settings["label"]}</#{h}><p>#{length(rows)} points</p>)}
  end

  def render(:content, assigns), do: Macaw.Component.Drawn.render(assigns.drawn, assigns.context)
end

defmodule Macaw.Test.Counter do
  @moduledoc false
  # A contained component: its value counts the rows delivered to it.
  use Macaw.Component, name: "test.counter", kinds: [:content]

  @impl true
  def declarations(_settings), do: {:ok, slots: %{"rows" => %{}}, isolation: :contained}

  @impl true
  def init(_settings, context), do: %{rows: 0, size: context.size, instance: context.instance}
  @impl true
  def delivery(value, _slot, delivery),
    do: %{value | rows: value.rows + length(Macaw.Data.Delivery.rows(delivery))}

  @impl true
  def size(value, size), do: %{value | size: size}
  @impl true
  def bound(value, _name, _new), do: value

  @impl true
  def render(:content, %{drawn: :live, value: value}), do: {:safe, "<p>#{value.rows} rows</p>"}
  def render(:content, assigns), do: Macaw.Component.Drawn.render(assigns.drawn, assigns.context)
end

defmodule Macaw.Test.SurfacePackage do
  @moduledoc false
  def __members__, do: [Macaw.Test.Note, Macaw.Test.Series, Macaw.Test.Counter]
end

defmodule Macaw.Test.Bound do
  @moduledoc false
  # A pure component that reads its rows by the fields its context binds, never by name.
  use Macaw.Component, name: "test.bound", kinds: [:content]

  alias Macaw.Component.Context

  @impl true
  def declarations(_settings),
    do:
      {:ok,
       slots: %{
         "points" => %{
           requires: %{
             "x" => %{type: :time, window: true},
             "y" => %{type: :number},
             "label" => %{type: :category, optional: true}
           }
         }
       }}

  @impl true
  def render(:content, %{drawn: :live} = assigns) do
    ctx = assigns.context
    {x, y} = {Context.field(ctx, "points", "x"), Context.field(ctx, "points", "y")}
    rows = assigns.deliveries |> Map.fetch!("points") |> Macaw.Data.Delivery.rows()
    sum = rows |> Enum.map(&Map.fetch!(&1, y)) |> Enum.sum()

    {:safe,
     ~s(<p>x=#{x} y=#{y} label=#{inspect(Context.field(ctx, "points", "label"))} sum=#{sum}</p>)}
  end

  def render(:content, assigns), do: Macaw.Component.Drawn.render(assigns.drawn, assigns.context)
end

defmodule Macaw.Test.BoundCounter do
  @moduledoc false
  # A contained component whose value takes its bound field from the context at init.
  use Macaw.Component, name: "test.bound_counter", kinds: [:content]

  @impl true
  def declarations(_settings),
    do:
      {:ok, slots: %{"points" => %{requires: %{"y" => %{type: :number}}}}, isolation: :contained}

  @impl true
  def init(_settings, context), do: %{y: Macaw.Component.Context.field(context, "points", "y")}
  @impl true
  def delivery(value, _slot, _delivery), do: value
  @impl true
  def size(value, _size), do: value
  @impl true
  def bound(value, _name, _new), do: value

  @impl true
  def render(:content, %{drawn: :live, value: value}), do: {:safe, "<p>reads #{value.y}</p>"}
  def render(:content, assigns), do: Macaw.Component.Drawn.render(assigns.drawn, assigns.context)
end

defmodule Macaw.Test.BoundPackage do
  @moduledoc false
  def __members__, do: [Macaw.Test.Bound, Macaw.Test.BoundCounter]
end
