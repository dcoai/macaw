defmodule Macaw.Test.Rows do
  @moduledoc false
  # A source over fixed rows, for surfaces' tests: it honors its params and the budget,
  # reports each fetch to `notify`, and fails as `mode` asks (:ok, :error, :crash, :hang,
  # :capped, :undescribable).
  @behaviour Macaw.Data.Source

  alias Macaw.Data.{Delivery, Schema}
  alias Macaw.Data.Source.Description

  defstruct schema: nil, rows: [], params: %{}, mode: :ok, notify: nil, name: "rows"

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
        supports: [:budget]
      )

  @impl true
  def fetch(%__MODULE__{} = source, request) do
    if source.notify,
      do: send(source.notify, {:fetched, source.name, request.budget, request.params})

    case source.mode do
      :error ->
        {:error, :down}

      :crash ->
        raise "the source crashed"

      :hang ->
        Process.sleep(:infinity)

      mode ->
        rows = if request.budget, do: Enum.take(source.rows, request.budget), else: source.rows

        {:ok,
         Delivery.new(rows,
           types: %{"t" => :time, "v" => :number, "host" => :category},
           schema: Schema.version(source.schema || @default),
           served: [
             capped: mode == :capped,
             reduced_by: if(length(rows) < length(source.rows), do: :source),
             params: request.params
           ]
         )}
    end
  end
end
