defmodule Bland.Polar do
  @moduledoc """
  Polar coordinate projection and helpers.

  ![Cardioid and |cos 3θ| on polar axes](assets/hero_polar.svg)

  When a figure has `projection: :polar`, series data is interpreted
  as `{θ, r}` pairs where `θ` is in **radians** and `r` is the radius
  from the origin. The renderer projects each point through
  `(θ, r) → (r·cos θ, r·sin θ)` before applying the usual x/y scales.

  The convention matches Matplotlib / Wolfram / most scientific
  plotting libraries: `θ = 0` is on the positive x-axis (3 o'clock),
  and angles increase counterclockwise.

  Prefer `Bland.polar_figure/1` + `Bland.polar_grid/2` over building
  this up by hand — they wire together the projection, a circular clip,
  and the concentric / radial reference grid in one shot.

  ## Examples

      iex> {x, y} = Bland.Polar.project({0.0, 1.0})
      iex> {Float.round(x, 6), Float.round(y, 6)}
      {1.0, 0.0}

      iex> {x, y} = Bland.Polar.project({:math.pi() / 2, 2.0})
      iex> {Float.round(x, 6), Float.round(y, 6)}
      {0.0, 2.0}
  """

  @doc """
  Project `{θ, r}` (polar, θ in radians) to `{x, y}` (Cartesian).
  """
  @spec project({number(), number()}) :: {float(), float()}
  def project({theta, r}) do
    {r * :math.cos(theta) * 1.0, r * :math.sin(theta) * 1.0}
  end

  @doc "Inverse of `project/1`: Cartesian → `{θ, r}`."
  @spec from_xy({number(), number()}) :: {float(), float()}
  def from_xy({x, y}) do
    {:math.atan2(y, x) * 1.0, :math.sqrt(x * x + y * y) * 1.0}
  end

  @doc """
  Produces `{thetas, rs}` tracing a full circle of radius `r` — useful
  for drawing concentric reference rings on a polar plot.
  """
  @spec circle(number(), pos_integer()) :: {[float()], [float()]}
  def circle(r, n \\ 120) when n > 2 do
    step = 2 * :math.pi() / n
    thetas = Enum.map(0..n, fn i -> i * step end)
    rs = List.duplicate(r * 1.0, n + 1)
    {thetas, rs}
  end
end
