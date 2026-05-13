defmodule Bland.DateTime do
  @moduledoc """
  Date-axis support: conversion to a numeric representation, calendar-
  snapped tick generation, and `strftime`-based label formatting.

  When a figure has `xscale: :date` (or `yscale: :date`), BLAND
  interprets axis values as epoch days — the integer day count since
  `~D[0000-01-01]`. Series builders auto-convert `Date.t()` to this
  representation, and the renderer picks tick positions on calendar
  boundaries (month, quarter, or year starts depending on span).

  Format the labels via the `:xtick_format` / `:ytick_format` option on
  `Bland.axes/2`. The format string is passed through to
  `Calendar.strftime/2`. The default format is picked from the chosen
  tick interval so labels stay legible at any zoom:

    * span < 60 days  → `"%b %d"` (e.g. `"Mar 14"`)
    * span < 1 yr     → `"%b %Y"` (e.g. `"Mar 2024"`)
    * span < 3 yr     → `"%b %Y"` (quarter ticks)
    * span ≥ 3 yr     → `"%Y"` (year ticks)
  """

  @epoch ~D[0000-01-01]

  @doc """
  Converts a `Date.t()` to its numeric axis value (epoch days since
  `~D[0000-01-01]`).

      iex> Bland.DateTime.date_to_axis(~D[0000-01-01])
      0

      iex> Bland.DateTime.date_to_axis(~D[2024-01-01]) > 700_000
      true
  """
  @spec date_to_axis(Date.t()) :: integer()
  def date_to_axis(%Date{} = d), do: Date.diff(d, @epoch)

  @doc "Inverse of `date_to_axis/1`."
  @spec axis_to_date(number()) :: Date.t()
  def axis_to_date(days) when is_number(days), do: Date.add(@epoch, trunc(days))

  @doc """
  Returns `{tick_axis_values, default_format}` for the given axis-space
  domain `{lo, hi}` (epoch days) and approximate target tick count.

  The format string picks an interval that yields roughly `target`
  ticks across the span:

    * span ≤ 60 days  → daily/weekly snap
    * span ≤ 1 year   → month-start snap
    * span ≤ 3 years  → quarter-start snap
    * span > 3 years  → year-start snap

  Ticks are *calendar-snapped*: month ticks land on day-1 of each
  month, quarter ticks on Jan/Apr/Jul/Oct, year ticks on Jan 1.
  """
  @spec nice_ticks({number(), number()}, pos_integer()) ::
          {[integer()], String.t()}
  def nice_ticks({lo, hi}, target \\ 6) when lo < hi do
    lo_d = axis_to_date(lo)
    hi_d = axis_to_date(hi)
    span_days = Date.diff(hi_d, lo_d)

    {interval, fmt} = pick_interval(span_days, target)
    ticks = generate_ticks(lo_d, hi_d, interval)

    {Enum.map(ticks, &date_to_axis/1), fmt}
  end

  @doc "Formats an axis value as a date string via `Calendar.strftime/2`."
  @spec format(number(), String.t()) :: String.t()
  def format(days, fmt) when is_number(days) and is_binary(fmt) do
    Calendar.strftime(axis_to_date(days), fmt)
  end

  # -------------------------------------------------------------------------
  # Interval selection
  # -------------------------------------------------------------------------

  # Returns {interval_atom, default_format_string}
  defp pick_interval(span_days, target) do
    cond do
      span_days <= 0 ->
        {{:day, 1}, "%b %d"}

      # Sub-month: pick a day stride that targets roughly `target` ticks
      span_days <= 60 ->
        stride = max(1, round(span_days / target))
        stride = snap_day_stride(stride)
        {{:day, stride}, "%b %d"}

      # Month-scale
      span_days <= 366 ->
        stride = max(1, round(span_days / 30 / target))
        stride = snap_month_stride(stride)
        {{:month, stride}, "%b %Y"}

      # Quarter-scale (1–3 years)
      span_days <= 366 * 3 ->
        {{:month, 3}, "%b %Y"}

      # Year-scale
      true ->
        stride = max(1, round(span_days / 366 / target))
        stride = snap_year_stride(stride)
        fmt = if stride >= 5, do: "%Y", else: "%Y"
        {{:year, stride}, fmt}
    end
  end

  defp snap_day_stride(s) when s <= 1, do: 1
  defp snap_day_stride(s) when s <= 2, do: 2
  defp snap_day_stride(s) when s <= 5, do: 5
  defp snap_day_stride(s) when s <= 7, do: 7
  defp snap_day_stride(s) when s <= 14, do: 14
  defp snap_day_stride(_), do: 30

  defp snap_month_stride(s) when s <= 1, do: 1
  defp snap_month_stride(s) when s <= 2, do: 2
  defp snap_month_stride(s) when s <= 3, do: 3
  defp snap_month_stride(s) when s <= 6, do: 6
  defp snap_month_stride(_), do: 12

  defp snap_year_stride(s) when s <= 1, do: 1
  defp snap_year_stride(s) when s <= 2, do: 2
  defp snap_year_stride(s) when s <= 5, do: 5
  defp snap_year_stride(s) when s <= 10, do: 10
  defp snap_year_stride(s) when s <= 20, do: 20
  defp snap_year_stride(_), do: 50

  # -------------------------------------------------------------------------
  # Calendar-snapped tick generation
  # -------------------------------------------------------------------------

  defp generate_ticks(lo, hi, {:day, stride}) do
    # Snap to the nearest stride-aligned day at or after `lo`.
    days_since_epoch = Date.diff(lo, @epoch)
    aligned_start = Date.add(@epoch, ceil_to(days_since_epoch, stride))
    take_until(aligned_start, hi, fn d -> Date.add(d, stride) end)
  end

  defp generate_ticks(lo, hi, {:month, stride}) do
    # Snap to first day of a stride-aligned month at or after `lo`.
    start_month = snap_month_start(lo, stride)
    take_until(start_month, hi, fn d -> advance_months(d, stride) end)
  end

  defp generate_ticks(lo, hi, {:year, stride}) do
    start_year = snap_year_start(lo, stride)
    take_until(start_year, hi, fn %Date{year: y, month: m, day: d} ->
      Date.new!(y + stride, m, d)
    end)
  end

  defp snap_month_start(%Date{year: y, month: m}, stride) do
    # Quantize the month to a stride-aligned boundary.
    m_aligned =
      cond do
        stride == 1 -> m
        # For multi-month strides, anchor on Jan and step forward.
        true ->
          # Find the smallest k where (k * stride + 1) >= m
          k = div(m - 1, stride)
          k = if rem(m - 1, stride) == 0 and m == k * stride + 1, do: k, else: k + 1
          target = k * stride + 1

          if target > 12 do
            12
          else
            target
          end
      end

    {y2, m2} =
      if m_aligned > 12 do
        {y + 1, m_aligned - 12}
      else
        {y, m_aligned}
      end

    case Date.new(y2, m2, 1) do
      {:ok, d} -> d
      {:error, _} -> Date.new!(y2 + 1, 1, 1)
    end
  end

  defp snap_year_start(%Date{year: y}, stride) do
    aligned_y = ceil_to(y, stride)
    Date.new!(aligned_y, 1, 1)
  end

  defp advance_months(%Date{year: y, month: m}, stride) do
    total = m + stride - 1
    new_year = y + div(total, 12)
    new_month = rem(total, 12) + 1
    Date.new!(new_year, new_month, 1)
  end

  defp take_until(start, hi, advance) do
    Stream.iterate(start, advance)
    |> Stream.take_while(fn d -> Date.compare(d, hi) != :gt end)
    |> Enum.to_list()
  end

  defp ceil_to(n, k) when k > 0 do
    case rem(n, k) do
      0 -> n
      r when n >= 0 -> n + (k - r)
      r -> n - r
    end
  end
end
