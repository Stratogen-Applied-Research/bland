defmodule Bland.Markers do
  @moduledoc """
  Scatter-point markers in the monochrome technical-drawing tradition.

  Each marker is drawn as a self-contained SVG fragment at a pixel point.
  Presets alternate between *open* (stroke-only) and *filled* shapes so
  that overlapping series stay distinguishable without color.

  ## Presets

    * `:circle_open`
    * `:circle_filled`
    * `:square_open`
    * `:square_filled`
    * `:triangle_open`
    * `:triangle_filled`
    * `:diamond_open`
    * `:diamond_filled`
    * `:cross`     — saltire (×)
    * `:plus`      — upright cross (+)
    * `:asterisk`  — six-spoke star
    * `:dot`       — 1-pixel dot for dense scatters
  """

  alias Bland.Svg

  @preset_order [
    :circle_open,
    :square_open,
    :triangle_open,
    :diamond_open,
    :cross,
    :plus,
    :circle_filled,
    :square_filled,
    :triangle_filled,
    :diamond_filled,
    :asterisk,
    :dot
  ]

  @doc "Markers in recommended cycling order."
  @spec preset_cycle() :: [atom()]
  def preset_cycle, do: @preset_order

  @doc "Next marker at cyclic `index`, skipping any in `exclude`."
  @spec cycle(non_neg_integer(), [atom()]) :: atom()
  def cycle(index, exclude \\ []) do
    pool = @preset_order -- exclude
    Enum.at(pool, rem(index, length(pool)))
  end

  @doc """
  Renders a marker at `(cx, cy)` pixel coordinates.

  Options:
    * `:size` (default `5`) — radius-like size parameter in px
    * `:stroke` (default `"black"`) — stroke color for open markers
    * `:fill` (default `"black"`) — fill for filled markers
    * `:stroke_width` (default `1`)
  """
  @spec draw(atom(), number(), number(), keyword()) :: iodata()
  def draw(marker, cx, cy, opts \\ []) do
    size = Keyword.get(opts, :size, 5)
    stroke = Keyword.get(opts, :stroke, "black")
    fill = Keyword.get(opts, :fill, "black")
    sw = Keyword.get(opts, :stroke_width, 1)
    render(marker, cx, cy, size, stroke, fill, sw)
  end

  # --- rendering ------------------------------------------------------------

  defp render(:circle_open, cx, cy, r, stroke, _fill, sw),
    do: Svg.circle(cx, cy, r, fill: "none", stroke: stroke, stroke_width: sw)

  defp render(:circle_filled, cx, cy, r, _stroke, fill, _sw),
    do: Svg.circle(cx, cy, r, fill: fill)

  defp render(:square_open, cx, cy, s, stroke, _fill, sw),
    do: Svg.rect(cx - s, cy - s, 2 * s, 2 * s, fill: "none", stroke: stroke, stroke_width: sw)

  defp render(:square_filled, cx, cy, s, _stroke, fill, _sw),
    do: Svg.rect(cx - s, cy - s, 2 * s, 2 * s, fill: fill)

  defp render(:triangle_open, cx, cy, s, stroke, _fill, sw) do
    Svg.polygon(triangle_points(cx, cy, s),
      fill: "none",
      stroke: stroke,
      stroke_width: sw,
      stroke_linejoin: "miter"
    )
  end

  defp render(:triangle_filled, cx, cy, s, _stroke, fill, _sw),
    do: Svg.polygon(triangle_points(cx, cy, s), fill: fill)

  defp render(:diamond_open, cx, cy, s, stroke, _fill, sw),
    do:
      Svg.polygon(diamond_points(cx, cy, s),
        fill: "none",
        stroke: stroke,
        stroke_width: sw
      )

  defp render(:diamond_filled, cx, cy, s, _stroke, fill, _sw),
    do: Svg.polygon(diamond_points(cx, cy, s), fill: fill)

  defp render(:cross, cx, cy, s, stroke, _fill, sw) do
    [
      Svg.line(cx - s, cy - s, cx + s, cy + s, stroke: stroke, stroke_width: sw),
      Svg.line(cx - s, cy + s, cx + s, cy - s, stroke: stroke, stroke_width: sw)
    ]
  end

  defp render(:plus, cx, cy, s, stroke, _fill, sw) do
    [
      Svg.line(cx - s, cy, cx + s, cy, stroke: stroke, stroke_width: sw),
      Svg.line(cx, cy - s, cx, cy + s, stroke: stroke, stroke_width: sw)
    ]
  end

  defp render(:asterisk, cx, cy, s, stroke, _fill, sw) do
    [
      Svg.line(cx - s, cy, cx + s, cy, stroke: stroke, stroke_width: sw),
      Svg.line(cx - s * 0.5, cy - s * 0.866, cx + s * 0.5, cy + s * 0.866,
        stroke: stroke, stroke_width: sw),
      Svg.line(cx - s * 0.5, cy + s * 0.866, cx + s * 0.5, cy - s * 0.866,
        stroke: stroke, stroke_width: sw)
    ]
  end

  defp render(:dot, cx, cy, _s, _stroke, fill, _sw),
    do: Svg.circle(cx, cy, 0.8, fill: fill)

  defp triangle_points(cx, cy, s) do
    # Equilateral, pointing up.
    [{cx, cy - s}, {cx + s * 0.866, cy + s * 0.5}, {cx - s * 0.866, cy + s * 0.5}]
  end

  defp diamond_points(cx, cy, s),
    do: [{cx, cy - s}, {cx + s, cy}, {cx, cy + s}, {cx - s, cy}]
end
