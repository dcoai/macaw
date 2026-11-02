defmodule Macaw.Test.Rows do
  @moduledoc false
  # A source over fixed rows, for surfaces' tests: it honors its params and the budget,
  # reports each fetch to `notify`, and fails as `mode` asks (:ok, :error, :crash, :hang,
  # :capped, :undescribable). It supports `supports` (`[:budget]` by default); one that
  # supports `:order` serves its rows in the request's order before it takes the budget.
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.{Description, Order}

  defstruct schema: nil,
            rows: [],
            params: %{},
            mode: :ok,
            notify: nil,
            name: "rows",
            supports: [:budget]

  @default Schema.new!(%{
             "t" => %{type: :time},
             "v" => %{type: :number, quantity: :duration, unit: "ms"},
             "host" => %{type: :category, identity: true}
           })

  def default_schema, do: @default

  @impl true
  def describe(%__MODULE__{mode: :undescribable}, _context), do: {:error, :unreachable}

  def describe(%__MODULE__{} = source, _context),
    do:
      Description.new(
        schema: source.schema || @default,
        params: source.params,
        supports: source.supports
      )

  @impl true
  def fetch(%__MODULE__{} = source, request) do
    if source.notify,
      do: send(source.notify, {:fetched, source.name, request.budget, request.params})

    if source.notify && request.order != [],
      do: send(source.notify, {:ordered, source.name, request.order})

    case source.mode do
      :error ->
        {:error, :down}

      :crash ->
        raise "the source crashed"

      :hang ->
        Process.sleep(:infinity)

      mode ->
        schema = source.schema || @default
        orders? = :order in source.supports
        rows = if orders?, do: Order.sort!(source.rows, request.order, schema), else: source.rows

        rows =
          if request.budget && :budget in source.supports,
            do: Enum.take(rows, request.budget),
            else: rows

        # Delivery.new/2 answers {:ok, delivery}, a source's answer.
        Delivery.new(rows,
          types: %{"t" => :time, "v" => :number, "host" => :category},
          schema: Schema.version(source.schema || @default),
          served: [
            capped: mode == :capped,
            reduced_by: if(length(rows) < length(source.rows), do: :source),
            ordered: if(orders? and request.order != [], do: :source),
            params: request.params
          ]
        )
    end
  end
end
