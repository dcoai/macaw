defmodule Macaw.Builtin.Reading do
  @moduledoc """
  One number from a slot's rows, as the built-in stat and meter read it (spec/05 §6.3,
  §6.4): the statistic a `reduce` setting names, over the field bound to the `value` role,
  in the delivered rows.

  `latest` and `delta` need the rows in time order, so a component using them asks its
  source for them newest first by its `t` role (`order/1`), and `latest` needs only one
  (`budget/1`). A slot with no time field has no latest: that is `:needs_time`, drawn
  `invalid` rather than an arbitrary row called the newest. **Absence is never zero:** a
  slot whose values are all gaps answers `nil`, whatever the statistic (`count` excepted,
  which counts them as none).
  """

  alias Macaw.Component.Context
  alias Macaw.Data.{Delivery, Ops, Table}

  @reduces ~w(latest delta sum mean min max median count)
  @ordered ~w(latest delta)

  @doc "The `reduce` parameter's legal values."
  @spec reduces() :: [String.t(), ...]
  def reduces, do: @reduces

  @doc "The order a `reduce` asks of the slot: newest first by its `t` role, or none."
  @spec order(String.t()) :: Macaw.Component.order()
  def order(reduce) when reduce in @ordered, do: [{{:role, "t"}, :desc}]
  def order(_reduce), do: []

  @doc "The rows a `reduce` needs: one for `latest`, else every row up to the ceiling."
  @spec budget(String.t()) :: pos_integer() | nil
  def budget("latest"), do: 1
  def budget(_reduce), do: nil

  @doc """
  The notice a capped or stale delivery draws above the number, or none for one that is
  the whole answer to what was asked. `latest` asks for one row, so it is always reduced;
  when those are the first rows in its order, nothing is missing. It keeps the notice when
  the source cut its rows before they were ordered (`:sample`, which may not be the newest)
  or says it stopped short (`capped`), and every other statistic keeps it, having read only
  part of the data.
  """
  @spec notice(Macaw.Component.Drawn.t(), Delivery.t(), Context.t(), String.t()) ::
          Phoenix.HTML.Safe.t() | nil
  def notice(:capped, %Delivery{served: %{capped: false, ordered: ordered}}, _context, "latest")
      when ordered in [:source, :runtime],
      do: nil

  def notice(drawn, _delivery, context, _reduce), do: Macaw.Component.Drawn.render(drawn, context)

  @doc """
  The number `reduce` answers over a live slot's rows: `{:ok, number}`, `{:ok, nil}` for
  no readings, `:needs_time` for `latest` or `delta` with no time field, and `:no_rows` for
  rows that don't pack.
  """
  @spec value(Delivery.t(), Context.t(), String.t()) ::
          {:ok, number() | nil} | :needs_time | :no_rows
  def value(%Delivery{} = delivery, %Context{} = context, reduce) do
    with {:ok, table} <- Delivery.table(delivery),
         {:ok, rows} <- Table.rows(table) do
      field = Context.field(context, "rows", "value") || "value"
      read(reduce, Enum.map(rows, &Map.get(&1, field)), Context.field(context, "rows", "t"))
    else
      {:error, _faults} -> :no_rows
    end
  end

  # Rows come newest first when the order was answered, whoever answered it.
  defp read(reduce, _values, nil) when reduce in @ordered, do: :needs_time
  defp read("latest", [newest | _], _time), do: {:ok, newest}
  defp read("latest", [], _time), do: {:ok, nil}
  defp read("delta", values, _time), do: statistic("delta", Enum.reverse(values))
  defp read(reduce, values, _time), do: statistic(reduce, values)

  defp statistic(reduce, values) do
    readings = Enum.reject(values, &is_nil/1)

    cond do
      reduce == "count" -> Ops.aggregate(readings, "count")
      readings == [] -> {:ok, nil}
      true -> Ops.aggregate(readings, reduce)
    end
    |> case do
      {:ok, _number} = answer -> answer
      {:error, _faults} -> :no_rows
    end
  end

  @doc """
  A number as text: at `digits` decimal places when given, else as it is.
  """
  @spec format(number(), non_neg_integer() | nil) :: String.t()
  def format(number, nil) when is_integer(number), do: Integer.to_string(number)
  def format(number, nil) when is_float(number), do: :erlang.float_to_binary(number, [:short])

  def format(number, digits) when is_integer(digits) and digits > 0,
    do: :erlang.float_to_binary(number * 1.0, decimals: digits)

  def format(number, 0), do: number |> round() |> Integer.to_string()
end
