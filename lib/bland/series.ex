defmodule Bland.Series do
  @moduledoc """
  Series data structures.

  Each series type is a struct tagged by its `:type` field, consumed by the
  renderer. Series are plain data; they do not carry any rendering state.

  ## Types

    * `Bland.Series.Line`      — connected polyline
    * `Bland.Series.Scatter`   — discrete points with markers
    * `Bland.Series.Bar`       — categorical bars with hatched fills
    * `Bland.Series.Histogram` — binned observations (numeric x-axis)
    * `Bland.Series.Heatmap`   — 2D grid of hatched cells
    * `Bland.Series.Contour`   — iso-level curves on a 2D grid
    * `Bland.Series.Area`      — filled region between a curve and a baseline
    * `Bland.Series.Polygon`   — closed filled polygon
    * `Bland.Series.ErrorBar`  — points with X/Y uncertainty whiskers
    * `Bland.Series.BoxPlot`   — box-and-whisker summary per category
    * `Bland.Series.Stem`      — vertical stems with markers (DSP)
    * `Bland.Series.Quiver`    — 2D arrow vector field
    * `Bland.Series.Hline`     — horizontal reference line
    * `Bland.Series.Vline`     — vertical reference line

  Prefer the builder helpers in `Bland` rather than instantiating these
  directly.
  """

  defmodule Line do
    @moduledoc "Line series. See `Bland.line/4`."
    defstruct type: :line,
              xs: [],
              ys: [],
              label: nil,
              stroke: nil,
              stroke_width: nil,
              markers: false,
              marker: nil,
              marker_size: nil
  end

  defmodule Scatter do
    @moduledoc "Scatter series. See `Bland.scatter/4`."
    defstruct type: :scatter,
              xs: [],
              ys: [],
              label: nil,
              marker: nil,
              marker_size: nil,
              stroke_width: nil
  end

  defmodule Bar do
    @moduledoc """
    Bar series. `categories` is a list of labels (used for the x axis);
    `values` is the corresponding numeric list. See `Bland.bar/4`.

    `:group` is an optional bucket key — bars sharing the same `group` are
    placed side-by-side in the same category slot, which is how grouped
    bar charts are constructed.
    """
    defstruct type: :bar,
              categories: [],
              values: [],
              label: nil,
              hatch: nil,
              group: :default,
              stroke_width: nil
  end

  defmodule Histogram do
    @moduledoc """
    Histogram series. See `Bland.histogram/3` and `Bland.Histogram`.

    Unlike `Bar`, histograms render on a *numeric* x-axis: bars sit
    flush against each other at their bin boundaries, with no category
    slots and no per-bar padding.

    Fields:
      * `:bin_edges` — strictly increasing list, length `n + 1`
      * `:values`    — length `n`; interpretation depends on `:normalize`
      * `:normalize` — `:count | :pmf | :density | :cmf`
      * `:density`   — backwards-compat boolean; `true` iff
        `:normalize` is `:density`
    """
    defstruct type: :histogram,
              bin_edges: [],
              values: [],
              label: nil,
              hatch: nil,
              stroke_width: nil,
              normalize: :count,
              density: false
  end

  defmodule Heatmap do
    @moduledoc """
    2D grid rendered as hatched cells. See `Bland.heatmap/3` and
    `Bland.Heatmap`.

    Fields:
      * `:data`    — list of rows; each row is a list of numbers.
        With `origin: :bottom_left` (default), `data` is addressed
        `data[row][col]` where row 0 is the bottom row.
      * `:x_edges` — list of length `cols + 1` giving column boundaries
      * `:y_edges` — list of length `rows + 1` giving row boundaries
      * `:ramp`    — list of pattern presets (light → dark). The cell
        value is quantized to `length(ramp)` levels.
      * `:range`   — `{lo, hi}` used for quantization. `:auto` derives
        from data.
      * `:origin`  — `:bottom_left` (default) or `:top_left` for
        matrix-style display where row 0 is the top row.
    """
    defstruct type: :heatmap,
              data: [],
              x_edges: nil,
              y_edges: nil,
              label: nil,
              ramp: nil,
              range: :auto,
              origin: :bottom_left
  end

  defmodule Area do
    @moduledoc """
    Filled area between a curve and a baseline. `baseline` defaults to
    `0.0`. See `Bland.area/4`.
    """
    defstruct type: :area,
              xs: [],
              ys: [],
              baseline: 0.0,
              label: nil,
              hatch: nil,
              stroke: :solid,
              stroke_width: nil
  end

  defmodule ErrorBar do
    @moduledoc """
    Error-bar series — discrete `(x, y)` points with optional X
    and/or Y uncertainty whiskers.

    Fields:
      * `:xs`, `:ys` — data points (length n)
      * `:yerr`   — list of y half-widths (symmetric) or `{lo, hi}`
        tuples (asymmetric); `nil` disables y whiskers
      * `:xerr`   — same for x
      * `:marker` — preset or `nil`. When `nil`, only whiskers are drawn.
      * `:marker_size`
      * `:cap_width` — whisker cap in px (default `4`)
      * `:stroke_width`, `:label`
    """
    defstruct type: :errorbar,
              xs: [],
              ys: [],
              yerr: nil,
              xerr: nil,
              label: nil,
              marker: :circle_filled,
              marker_size: nil,
              cap_width: 4,
              stroke_width: nil
  end

  defmodule BoxPlot do
    @moduledoc """
    Box-and-whisker series. One box per category.

    Fields:
      * `:categories` — list of category labels (one per box)
      * `:stats`      — list of maps, one per box, each with
        `%{min, q1, median, q3, max, outliers}` keys. `outliers`
        is a (possibly-empty) list of y-values rendered as open
        markers beyond the whiskers.
      * `:hatch`      — IQR box fill (default cycles)
      * `:label`      — legend label
      * `:stroke_width`, `:box_width` (fraction of slot; default 0.6)
    """
    defstruct type: :boxplot,
              categories: [],
              stats: [],
              label: nil,
              hatch: nil,
              stroke_width: nil,
              box_width: 0.6
  end

  defmodule Stem do
    @moduledoc """
    Stem-plot series — a vertical line from `baseline` to `(x, y)`
    with a marker at the tip. Canonical for discrete-time signals.

    Fields:
      * `:xs`, `:ys`
      * `:baseline` — stem start y (default `0`)
      * `:marker`, `:marker_size`, `:stroke`, `:stroke_width`, `:label`
    """
    defstruct type: :stem,
              xs: [],
              ys: [],
              baseline: 0.0,
              label: nil,
              marker: :circle_filled,
              marker_size: nil,
              stroke: :solid,
              stroke_width: nil
  end

  defmodule Contour do
    @moduledoc """
    Contour series — iso-level curves on a 2D scalar grid.

    Fields:
      * `:data`     — rows of numbers (same shape conventions as `Heatmap`)
      * `:x_edges`, `:y_edges` — length `cols + 1` / `rows + 1`
      * `:levels`   — list of scalar values at which to draw contours
      * `:origin`   — `:bottom_left` (default) or `:top_left`
      * `:label`    — legend label for the contour set
      * `:stroke`, `:stroke_width`
    """
    defstruct type: :contour,
              data: [],
              x_edges: nil,
              y_edges: nil,
              levels: [],
              origin: :bottom_left,
              label: nil,
              stroke: :solid,
              stroke_width: nil
  end

  defmodule Quiver do
    @moduledoc """
    Quiver series — a 2D vector field. Each `(x, y)` has an arrow
    pointing in the direction of `(u, v)` with length proportional
    to `√(u² + v²)`.

    Fields:
      * `:xs`, `:ys` — tail positions (length n)
      * `:us`, `:vs` — vector components at each tail (length n)
      * `:scale`   — multiplier applied to every vector before drawing
      * `:head_size` — arrow-head length in px (default `6`)
      * `:stroke`, `:stroke_width`, `:label`
    """
    defstruct type: :quiver,
              xs: [],
              ys: [],
              us: [],
              vs: [],
              scale: 1.0,
              head_size: 6,
              label: nil,
              stroke: :solid,
              stroke_width: nil
  end

  defmodule Polygon do
    @moduledoc """
    Closed filled polygon in data space. See `Bland.polygon/4`.

    Unlike `Area`, which sweeps a curve back to a baseline, `Polygon`
    fills whatever arbitrary shape its vertices describe. The last
    point is implicitly connected back to the first.

    Fields:
      * `:xs`, `:ys` — vertex coordinates (same length)
      * `:hatch`     — optional fill pattern. When `nil`, the polygon is
        stroke-only.
      * `:stroke`    — outline dash preset (default `:solid`)
      * `:stroke_width`, `:label`
    """
    defstruct type: :polygon,
              xs: [],
              ys: [],
              label: nil,
              hatch: nil,
              stroke: :solid,
              stroke_width: nil
  end

  defmodule Hline do
    @moduledoc "Horizontal reference line at `y`."
    defstruct type: :hline, y: 0.0, label: nil, stroke: :dashed, stroke_width: 1.0
  end

  defmodule Vline do
    @moduledoc "Vertical reference line at `x`."
    defstruct type: :vline, x: 0.0, label: nil, stroke: :dashed, stroke_width: 1.0
  end

  @doc """
  Returns `{min, max}` of the x-domain contributed by a series, or `nil`
  if the series has no x extent (e.g. `Hline`).
  """
  @spec x_extent(map()) :: {number(), number()} | nil
  def x_extent(%Line{xs: xs}), do: extent(xs)
  def x_extent(%Scatter{xs: xs}), do: extent(xs)
  def x_extent(%Area{xs: xs}), do: extent(xs)
  def x_extent(%Bar{categories: c}) when c != [], do: {0, length(c) - 1}
  def x_extent(%Histogram{bin_edges: []}), do: nil
  def x_extent(%Histogram{bin_edges: edges}),
    do: {List.first(edges), List.last(edges)}
  def x_extent(%Heatmap{x_edges: nil}), do: nil
  def x_extent(%Heatmap{x_edges: edges}),
    do: {List.first(edges), List.last(edges)}
  def x_extent(%Polygon{xs: xs}), do: extent(xs)
  def x_extent(%ErrorBar{xs: xs}), do: extent(xs)
  def x_extent(%Stem{xs: xs}), do: extent(xs)
  def x_extent(%Quiver{xs: xs, us: us}),
    do: merge_extents(extent(xs), extent(Enum.zip(xs, us) |> Enum.map(fn {x, u} -> x + u end)))
  def x_extent(%BoxPlot{categories: c}) when c != [], do: {0, length(c) - 1}
  def x_extent(%Contour{x_edges: nil}), do: nil
  def x_extent(%Contour{x_edges: edges}), do: {List.first(edges), List.last(edges)}
  def x_extent(%Vline{x: x}), do: {x, x}
  def x_extent(_), do: nil

  @doc """
  Returns `{min, max}` of the y-domain contributed by a series, or `nil`.
  """
  @spec y_extent(map()) :: {number(), number()} | nil
  def y_extent(%Line{ys: ys}), do: extent(ys)
  def y_extent(%Scatter{ys: ys}), do: extent(ys)
  def y_extent(%Area{ys: ys, baseline: base}), do: extent([base | ys])
  def y_extent(%Bar{values: v, group: _}), do: extent([0 | v])
  def y_extent(%Histogram{values: v}), do: extent([0 | v])
  def y_extent(%Heatmap{y_edges: nil}), do: nil
  def y_extent(%Heatmap{y_edges: edges}),
    do: {List.first(edges), List.last(edges)}
  def y_extent(%Polygon{ys: ys}), do: extent(ys)
  def y_extent(%ErrorBar{ys: ys, yerr: nil}), do: extent(ys)
  def y_extent(%ErrorBar{ys: ys, yerr: yerr}), do: errorbar_y_extent(ys, yerr)
  def y_extent(%Stem{ys: ys, baseline: b}), do: extent([b | ys])
  def y_extent(%Quiver{ys: ys, vs: vs}),
    do:
      merge_extents(
        extent(ys),
        extent(Enum.zip(ys, vs) |> Enum.map(fn {y, v} -> y + v end))
      )
  def y_extent(%BoxPlot{stats: stats}) do
    all =
      stats
      |> Enum.flat_map(fn s ->
        [s.min, s.max] ++ (Map.get(s, :outliers) || [])
      end)

    extent(all)
  end
  def y_extent(%Contour{y_edges: nil}), do: nil
  def y_extent(%Contour{y_edges: edges}), do: {List.first(edges), List.last(edges)}
  def y_extent(%Hline{y: y}), do: {y, y}
  def y_extent(_), do: nil

  @doc """
  Returns the x-axis *category* labels contributed by this series, or
  `nil` if the series is not categorical.
  """
  @spec categories(map()) :: [String.t()] | nil
  def categories(%Bar{categories: c}), do: c
  def categories(_), do: nil

  defp extent([]), do: nil

  defp extent(vals) do
    {min, max} = Enum.min_max(vals)
    {min, max}
  end

  defp merge_extents(nil, b), do: b
  defp merge_extents(a, nil), do: a

  defp merge_extents({lo1, hi1}, {lo2, hi2}),
    do: {min(lo1, lo2), max(hi1, hi2)}

  defp errorbar_y_extent(ys, yerr) do
    pairs = Enum.zip(ys, yerr)

    bounds =
      Enum.flat_map(pairs, fn
        {y, {lo, hi}} -> [y - lo, y + hi]
        {y, half} when is_number(half) -> [y - half, y + half]
        {y, _} -> [y]
      end)

    extent(bounds)
  end
end
