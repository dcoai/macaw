defmodule Macaw.Surface.Env do
  @moduledoc false
  # The values an `env` gives, judged one way by fetching and by `show/2` (spec/06 §3.5,
  # §3.7). Only a value that's there is judged: a key left out is its reader's to answer.
  #
  # The ceiling is judged here because a term that isn't a number doesn't fail a comparison
  # with one. It orders above every number, so `Finish.ceiling/2` would clamp nothing and
  # a safety limit would silently be off.

  alias Macaw.Component.Context

  @doc false
  # What fetching reads.
  @spec fetch_faults(keyword()) :: [{[atom(), ...], term()}]
  def fetch_faults(env) do
    for key <- [:ceiling, :now, :row_height, :timeout, :width],
        {:ok, value} <- [Keyword.fetch(env, key)],
        fault <- fault(key, value),
        do: fault
  end

  @doc false
  # What rendering reads beyond it, as a component's context would refuse it.
  @spec render_faults(keyword()) :: [{[atom(), ...], term()}]
  def render_faults(env) do
    given = Keyword.take(env, [:mode, :theme, :heading_level])
    filler = [mode: :socketless, instance: "env", size: {1, 1}, now: ~U[2000-01-01 00:00:00Z]]

    case Context.new(Keyword.merge(filler, given)) do
      {:ok, _context} -> []
      {:error, faults} -> faults
    end
  end

  defp fault(:ceiling, n) when is_integer(n) and n > 0, do: []
  defp fault(:ceiling, _value), do: [{[:ceiling], {:type, :pos_integer}}]
  defp fault(:now, %DateTime{}), do: []
  defp fault(:now, _value), do: [{[:now], {:type, :time}}]
  defp fault(:timeout, n) when is_integer(n) and n >= 0, do: []
  defp fault(:timeout, _value), do: [{[:timeout], {:type, :non_neg_integer}}]
  defp fault(_size, n) when is_number(n) and n > 0, do: []
  defp fault(size, _value), do: [{[size], {:type, :pos_number}}]
end
