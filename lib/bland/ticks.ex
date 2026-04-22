defmodule Bland.Ticks do
  @moduledoc """
  Nice-rounded tick generation.

  Picks evenly-spaced tick values within a domain using the classic
  1-2-2.5-5-10 decade decomposition so that axes break on numbers a human
  would pick by hand — the kind of axis you'd draw on engineering graph
  paper.

      iex> Bland.Ticks.nice({0.0, 9.7}, 5) |> Enum.take(3)
      [0.0, 2.0, 4.0]
  """

  @nice_steps [1.0, 2.0, 2.5, 5.0, 10.0]

  @doc """
  Produces a list of tick values for a linear axis. `target` is the
  approximate number of ticks desired; the returned list will be close to
  that count but pinned to nice, round step sizes.
  """
  @spec nice({number(), number()}, pos_integer()) :: [float()]
  def nice({d0, d1}, target \\ 6) when d0 != d1 and target > 1 do
    {lo, hi} = if d0 < d1, do: {d0, d1}, else: {d1, d0}
    step = nice_step((hi - lo) / target)
    start = :math.ceil(lo / step) * step
    stop = :math.floor(hi / step) * step
    n = round((stop - start) / step)

    Enum.map(0..n, fn i -> round_step(start + i * step, step) end)
  end

  @doc """
  Log-axis ticks at integer powers of `base` that fall within the domain.
  """
  @spec log_nice({number(), number()}, number()) :: [float()]
  def log_nice({d0, d1}, base \\ 10) when d0 > 0 and d1 > 0 and d0 != d1 do
    {lo, hi} = if d0 < d1, do: {d0, d1}, else: {d1, d0}
    lo_exp = trunc(:math.floor(:math.log(lo) / :math.log(base)))
    hi_exp = trunc(:math.ceil(:math.log(hi) / :math.log(base)))

    Enum.map(lo_exp..hi_exp//1, fn e -> :math.pow(base, e) end)
    |> Enum.filter(&(&1 >= lo and &1 <= hi))
  end

  @doc """
  Default tick formatter: trims trailing zeros from floats and renders
  integers without a decimal point.
  """
  @spec format(number()) :: String.t()
  def format(v) when is_integer(v), do: Integer.to_string(v)

  def format(v) when is_float(v) do
    cond do
      v == trunc(v) ->
        Integer.to_string(trunc(v))

      abs(v) >= 1_000_000 or (abs(v) < 0.001 and v != 0.0) ->
        :io_lib.format("~.2e", [v]) |> IO.iodata_to_binary()

      true ->
        :erlang.float_to_binary(v, decimals: 3) |> trim_trailing_zeros()
    end
  end

  defp trim_trailing_zeros(s) do
    s
    |> String.replace(~r/(\.\d*?)0+$/, "\\1")
    |> String.replace(~r/\.$/, "")
  end

  defp nice_step(raw) when raw > 0 do
    exp = :math.floor(:math.log10(raw))
    fraction = raw / :math.pow(10, exp)

    step_frac =
      Enum.find(@nice_steps, fn s -> s >= fraction end) || List.last(@nice_steps)

    step_frac * :math.pow(10, exp)
  end

  # Nudges accumulated floats back to the grid step so axis labels don't
  # drift into 1.0000000002 territory.
  defp round_step(value, step) do
    decimals = max(0, -floor_log10(step) |> trunc()) + 2
    Float.round(value, decimals)
  end

  defp floor_log10(x) when x > 0, do: :math.floor(:math.log10(x))
  defp floor_log10(_), do: 0
end
