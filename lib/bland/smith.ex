defmodule Bland.Smith do
  @moduledoc """
  Smith chart helpers.

  ![S11 sweep on a Smith chart](assets/hero_smith.svg)

  A Smith chart plots the reflection coefficient `Γ = (Z - 1) / (Z + 1)`
  on the unit disk, where `Z = r + jx` is a normalized complex impedance
  (usually normalized to `Z₀ = 50 Ω`). Constant-resistance circles and
  constant-reactance arcs form the classical grid.

  BLAND's approach: use a Cartesian figure where the x-axis is
  `Re(Γ)` and the y-axis is `Im(Γ)`. `Bland.smith_figure/1` sets the
  plot area up as a unit disk; `Bland.smith_grid/2` draws the
  resistance circles and reactance arcs. User data is plotted as
  reflection coefficients (Γ values) directly — convert from
  impedance via `gamma_from_z/1`.

  ## Examples

      iex> {re, im} = Bland.Smith.gamma_from_z({1.0, 0.0})
      iex> {Float.round(re, 6), Float.round(im, 6)}
      {0.0, 0.0}

      iex> {re, im} = Bland.Smith.gamma_from_z({0.0, 0.0})
      iex> {Float.round(re, 6), Float.round(im, 6)}
      {-1.0, 0.0}
  """

  @default_r_values [0.2, 0.5, 1.0, 2.0, 5.0]
  @default_x_values [0.2, 0.5, 1.0, 2.0, 5.0]

  @doc """
  Default resistance values (normalized) at which to draw the constant-R
  circles: `[0.2, 0.5, 1.0, 2.0, 5.0]`.
  """
  @spec default_r_values() :: [float()]
  def default_r_values, do: @default_r_values

  @doc """
  Default reactance magnitudes at which to draw the constant-X arcs.
  Each positive value also draws its negative counterpart:
  `[±0.2, ±0.5, ±1.0, ±2.0, ±5.0]`.
  """
  @spec default_x_values() :: [float()]
  def default_x_values, do: @default_x_values

  @doc """
  Converts normalized impedance `{r, x}` to reflection coefficient
  `{Re(Γ), Im(Γ)}`.

  For `Z = r + jx`, `Γ = (Z − 1) / (Z + 1)`.
  """
  @spec gamma_from_z({number(), number()}) :: {float(), float()}
  def gamma_from_z({r, x}) do
    denom = (r + 1) * (r + 1) + x * x
    {(r * r + x * x - 1) / denom, 2 * x / denom}
  end

  @doc """
  Inverse: reflection coefficient `{Γ_re, Γ_im}` to normalized
  impedance `{r, x}`. `Z = (1 + Γ) / (1 − Γ)`.
  """
  @spec z_from_gamma({number(), number()}) :: {float(), float()}
  def z_from_gamma({gr, gi}) do
    denom = (1 - gr) * (1 - gr) + gi * gi

    cond do
      denom == 0 -> {:infinity, :infinity}
      true -> {(1 - gr * gr - gi * gi) / denom, 2 * gi / denom}
    end
  end

  @doc """
  Full circle of constant normalized resistance `r`, traced in the
  Γ-plane. Returns `{xs, ys}` with `n + 1` points.

  The circle has center `(r/(r+1), 0)` and radius `1/(r+1)`; it sits
  entirely inside the unit disk, tangent at `(1, 0)`.
  """
  @spec r_circle(number(), pos_integer()) :: {[float()], [float()]}
  def r_circle(r, n \\ 120) when r >= 0 and n > 2 do
    cx = r / (r + 1)
    rad = 1.0 / (r + 1)
    trace_circle({cx, 0.0}, rad, n)
  end

  @doc """
  Full circle of constant normalized reactance `x` in the Γ-plane.
  Returns `{xs, ys}` with `n + 1` points.

  Center is `(1, 1/x)`, radius is `1/|x|`. Only the portion inside
  the unit disk is meaningful on a Smith chart; the series-layer clip
  (`clip: :circle`) masks the rest.
  """
  @spec x_arc(number(), pos_integer()) :: {[float()], [float()]}
  def x_arc(x, n \\ 120) when x != 0 and n > 2 do
    cx = 1.0
    cy = 1.0 / x
    rad = 1.0 / abs(x)
    trace_circle({cx, cy}, rad, n)
  end

  defp trace_circle({cx, cy}, rad, n) do
    step = 2 * :math.pi() / n

    points =
      Enum.map(0..n, fn i ->
        phi = i * step
        {cx + rad * :math.cos(phi), cy + rad * :math.sin(phi)}
      end)

    Enum.unzip(points)
  end
end
