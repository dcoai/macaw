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
