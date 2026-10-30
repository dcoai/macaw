defmodule Macaw.Surface.Render do
  @moduledoc false
  # Rendering a validated surface (spec/06 §3.6): its title at its level, then one `div`
  # per cell in reading order, with the grid's classes and the instance's id, each cell
  # rendered with its context, its drawn state, and its deliveries or its value.

  alias Macaw.Component
  alias Macaw.Component.{Assigns, Context}
  alias Macaw.Grid
  alias Macaw.Surface.Validated

  @defaults [mode: :socketless, heading_level: 2, width: 1200, row_height: 64]

  @doc false
  @spec render(Validated.t(), map(), keyword()) :: Phoenix.HTML.safe()
  def render(%Validated{} = validated, fetched, env) when is_map(fetched) and is_list(env) do
    env = Keyword.merge(@defaults, env)
    surface = validated.surface
    level = env[:heading_level]
    title = if surface.title, do: title(surface.title, level), else: []
    cell_level = if surface.title, do: min(level + 1, 6), else: level

    cells =
      for name <- validated.order do
        cell(validated, name, Map.fetch!(fetched, name), cell_level, env)
      end

    {:safe,
     [
       ~s(<div class="mw-surface" id="#{surface.name}">),
       title,
       ~s(<div class="mw-grid">),
       cells,
       "</div></div>"
     ]}
  end

  defp title(text, level),
    do: [~s(<h#{level} class="mw-surface-title">), escape(text), "</h#{level}>"]

  defp cell(validated, name, %{deliveries: deliveries, drawn: drawn}, level, env) do
    cell = Map.fetch!(validated.cells, name)
    place = Map.fetch!(validated.surface.cells, name).place
    kind = Map.fetch!(validated.surface.cells, name).kind
    instance = "#{validated.surface.name}-#{name}"

    {:ok, context} =
      Context.new(
        mode: env[:mode],
        instance: instance,
        size: Grid.size(place, env[:width], env[:row_height]),
        heading_level: level,
        theme: Keyword.get_lazy(env, :theme, &Macaw.Layers.Theme.default/0),
        now: Keyword.fetch!(env, :now),
        bindings: Map.new(cell.slots, fn {slot, %{fields: fields}} -> {slot, fields} end)
      )

    {deliveries, value} =
      case cell.declarations.isolation do
        :pure -> {deliveries, nil}
        :contained -> {%{}, value(cell, context, deliveries)}
      end

    {:ok, assigns} =
      Assigns.new(
        context: context,
        settings: cell.settings,
        declarations: cell.declarations,
        drawn: drawn,
        deliveries: deliveries,
        value: value
      )

    [
      ~s(<div class="#{Grid.classes(place)}" id="#{instance}">),
      cell.module.render(kind, assigns) |> Phoenix.HTML.Safe.to_iodata(),
      "</div>"
    ]
  end

  # A contained component's value: init, each delivered slot in name order, then its size.
  defp value(cell, context, deliveries) do
    value = Component.init(cell.module, cell.settings, context)

    value =
      deliveries
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.reduce(value, fn {slot, delivery}, v ->
        Component.delivery(cell.module, v, slot, delivery)
      end)

    Component.size(cell.module, value, context.size)
  end

  defp escape(text), do: text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
