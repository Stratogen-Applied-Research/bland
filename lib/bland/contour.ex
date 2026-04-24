defmodule Bland.Contour do
  @moduledoc """
  Marching-squares contour extraction for 2D scalar grids.

  ![Iso-level contours](assets/hero_contour.svg)

  Given a `rows × cols` grid of numeric values, `segments/5` produces a
  set of line segments in data space where the scalar field equals each
  requested level. The renderer draws these segments as `Contour` series
  output — iso-lines suitable for topography, isobars, field intensity,
  level sets of optimization landscapes.

  The algorithm:

    * For each cell (a 2×2 square of grid values), classify its four
      corners as above or below the target level.
    * Each classification gives a case index 0..15; the case tells us
      how many segments (0, 1, or 2) to emit through the cell and where
      they enter / exit on the cell boundary.
    * Each segment endpoint is linearly interpolated along the cell
      edge where the scalar value crosses the level.

  The 16-case table is unambiguous for 14 cases; the two saddle cases
  (5 and 10) are broken by the "mean of four corners" convention —
  adequate for typical scientific data.

  Output: `[{level, [{p1, p2}, {p3, p4}, ...]}, ...]` where each `p`
  is `{x, y}` in data space.
  """

  @type point :: {float(), float()}
  @type segment :: {point(), point()}

  @doc """
  Returns `[{level, [{{x1,y1}, {x2,y2}}, ...]}, ...]` — one entry per
  requested level.
  """
  @spec segments([[number()]], [number()], [number()], [number()], atom()) ::
          [{number(), [segment()]}]
  def segments(grid, x_edges, y_edges, levels, origin \\ :bottom_left) do
    # Map data row-index → the y_edges row-index it occupies.
    # For :bottom_left, data[0] occupies y_edges[0..1] (bottom row).
    # For :top_left,    data[0] occupies y_edges[n..n-1] (top row).
    rows = length(grid)
    y_index_fun =
      case origin do
        :top_left -> fn r -> rows - 1 - r end
        _ -> fn r -> r end
      end

    # Convert to a flat data getter for convenience. We want f(i, j) where
    # i is column and j is row, returning the scalar value, AND the
    # corresponding (x, y) corner positions.
    Enum.map(levels, fn level ->
      segs =
        for row <- 0..(rows - 2),
            col <- 0..(length(hd(grid)) - 2),
            reduce: [] do
          acc ->
            cell_segments(grid, x_edges, y_edges, y_index_fun, row, col, level) ++ acc
        end

      {level, segs}
    end)
  end

  # Returns 0, 1, or 2 segments for this cell at this level.
  defp cell_segments(grid, x_edges, y_edges, y_idx_fun, row, col, level) do
    # Cell corners in data space. Convention: (col, row) varies over the
    # grid; we translate to (x, y) using x_edges/y_edges.
    x_l = Enum.at(x_edges, col)
    x_r = Enum.at(x_edges, col + 1)

    # Row → y_edge index via y_idx_fun
    y_row = y_idx_fun.(row)
    y_row_next = y_idx_fun.(row + 1)
    y_b = Enum.at(y_edges, min(y_row, y_row_next))
    y_t = Enum.at(y_edges, max(y_row, y_row_next))

    # Corner values — we label by which corner in data space:
    #   BL = bottom-left, BR = bottom-right, TR = top-right, TL = top-left
    row_b = if y_row < y_row_next, do: row, else: row + 1
    row_t = if y_row < y_row_next, do: row + 1, else: row

    bl = get_value(grid, row_b, col)
    br = get_value(grid, row_b, col + 1)
    tr = get_value(grid, row_t, col + 1)
    tl = get_value(grid, row_t, col)

    # Build 4-bit case index: TL=8, TR=4, BR=2, BL=1 — each bit set iff
    # that corner is above `level`.
    index =
      bit(bl >= level, 1) +
        bit(br >= level, 2) +
        bit(tr >= level, 4) +
        bit(tl >= level, 8)

    # Edge interpolations:
    #   bottom — between BL and BR
    #   right  — between BR and TR
    #   top    — between TR and TL
    #   left   — between TL and BL
    bottom = fn -> {interp(x_l, x_r, bl, br, level), y_b} end
    right = fn -> {x_r, interp(y_b, y_t, br, tr, level)} end
    top = fn -> {interp(x_r, x_l, tr, tl, level), y_t} end
    left = fn -> {x_l, interp(y_t, y_b, tl, bl, level)} end

    case index do
      0 -> []
      15 -> []
      # Single-segment cases
      1 -> [{left.(), bottom.()}]
      2 -> [{bottom.(), right.()}]
      3 -> [{left.(), right.()}]
      4 -> [{right.(), top.()}]
      6 -> [{bottom.(), top.()}]
      7 -> [{left.(), top.()}]
      8 -> [{top.(), left.()}]
      9 -> [{top.(), bottom.()}]
      11 -> [{top.(), right.()}]
      12 -> [{right.(), left.()}]
      13 -> [{right.(), bottom.()}]
      14 -> [{bottom.(), left.()}]
      # Saddle cases (5 and 10) — disambiguate by center mean
      5 ->
        if (bl + br + tr + tl) / 4 >= level do
          [{left.(), top.()}, {right.(), bottom.()}]
        else
          [{left.(), bottom.()}, {right.(), top.()}]
        end

      10 ->
        if (bl + br + tr + tl) / 4 >= level do
          [{bottom.(), left.()}, {top.(), right.()}]
        else
          [{bottom.(), right.()}, {top.(), left.()}]
        end
    end
  end

  defp get_value(grid, row, col), do: grid |> Enum.at(row) |> Enum.at(col)

  defp bit(true, b), do: b
  defp bit(false, _), do: 0

  # Linear interp of the x-coord where the value passes through `level`
  # between v1 at x1 and v2 at x2.
  defp interp(x1, x2, v1, v2, _level) when v1 == v2, do: (x1 + x2) / 2

  defp interp(x1, x2, v1, v2, level) do
    t = (level - v1) / (v2 - v1)
    x1 + t * (x2 - x1)
  end
end
