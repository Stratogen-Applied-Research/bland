defmodule Bland.Heatmap do
  @moduledoc """
  Binning and ramp helpers for monochrome heatmaps.

  A heatmap renders a 2D grid of numeric values as shaded cells. In a
  monochrome world, shading comes from *hatch density* — we quantize
  each value to one of N levels, then fill each cell with the pattern
  assigned to that level.

  The default ramp walks from paper-white to full black in seven steps,
  with hatch orientation alternating to keep adjacent levels
  distinguishable even under poor reproduction:

      :solid_white → :dots_sparse → :diagonal → :crosshatch
                   → :diagonal_dense → :dots_dense → :solid_black

  You can override with any list of pattern preset atoms, or use the
  `ramp/1` helper to truncate or extend.

      iex> Bland.Heatmap.quantize(0.5, {0.0, 1.0}, 4)
      2

      iex> Bland.Heatmap.quantize(-1.0, {0.0, 1.0}, 4)
      0
  """

  @default_ramp [
    :solid_white,
    :dots_sparse,
    :diagonal,
    :crosshatch,
    :diagonal_dense,
    :dots_dense,
    :solid_black
  ]

  @doc "The default 7-level ramp, light to dark."
  @spec default_ramp() :: [atom()]
  def default_ramp, do: @default_ramp

  @doc """
  Returns a ramp of exactly `n` levels by sampling evenly from the
  default ramp.

      iex> Bland.Heatmap.ramp(3)
      [:solid_white, :crosshatch, :solid_black]
  """
  @spec ramp(pos_integer()) :: [atom()]
  def ramp(n) when n >= 2 do
    steps = length(@default_ramp) - 1

    Enum.map(0..(n - 1), fn i ->
      idx = round(i * steps / (n - 1))
      Enum.at(@default_ramp, idx)
    end)
  end

  def ramp(1), do: [:crosshatch]

  @doc """
  Maps `value` in `{lo, hi}` to a discrete level in `[0, n_levels)`.

  Values `<= lo` clamp to 0, values `>= hi` clamp to `n_levels - 1`.
  """
  @spec quantize(number(), {number(), number()}, pos_integer()) :: non_neg_integer()
  def quantize(_value, {lo, hi}, n) when lo == hi, do: div(n - 1, 2)

  def quantize(value, {lo, hi}, n) when is_number(value) do
    cond do
      value <= lo -> 0
      value >= hi -> n - 1
      true -> min(n - 1, trunc((value - lo) / (hi - lo) * n))
    end
  end

  @doc """
  Returns `{min, max}` of a nested list of numbers, ignoring non-numbers.

      iex> Bland.Heatmap.extent([[1, 2], [3, 4]])
      {1, 4}
  """
  @spec extent([[number()]]) :: {number(), number()}
  def extent(grid) do
    grid
    |> List.flatten()
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> {0.0, 1.0}
      nums -> Enum.min_max(nums)
    end
  end
end
