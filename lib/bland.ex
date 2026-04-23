defmodule Bland do
  @moduledoc """
  **BLAND — Elixir Technical Drawing.**

  A pure-Elixir library for producing monochrome, paper-ready plots in the
  visual tradition of 1960s–1980s engineering reports: thin black rules,
  serif type, crisp frames, hatched fills, and optional drafting title
  blocks.

  BLAND emits SVG. SVG is the right format for paper output — resolution-
  independent, prints clean on any printer, and embeds into Livebook, PDF
  pipelines, and LaTeX figures without conversion.

  > #### Design philosophy {: .info}
  >
  > BLAND deliberately avoids color. The library leans on the legibility
  > vocabulary of technical drafting — stroke weight, dash patterns, hatch
  > density, and marker shape — so plots stay readable in photocopies,
  > grayscale prints, and for readers with color vision deficiency.

  ## Quick start

      xs = Enum.map(0..100, &(&1 / 10.0))

      fig =
        Bland.figure(size: :a5_landscape, title: "Damped oscillation")
        |> Bland.axes(xlabel: "t [s]", ylabel: "x(t)")
        |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4) * :math.cos(&1))),
             label: "response", stroke: :solid)
        |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4))),
             label: "envelope", stroke: :dashed)
        |> Bland.legend(position: :top_right)

      Bland.to_svg(fig) |> File.write!("plot.svg")

  ## API overview

    * `figure/1`          — begin a new plot with canvas + theme
    * `axes/2`            — labels, limits, scale type, grid
    * `line/4`            — connected polyline (time series, curves)
    * `scatter/4`         — discrete marked points
    * `bar/4`             — categorical bars with hatched fills
    * `histogram/3`       — binned observations on a numeric axis
    * `heatmap/3`         — 2D grid shaded with a hatch ramp
    * `area/4`            — filled region with hatched fill
    * `colorbar/2`        — ramp legend for a heatmap
    * `graticule/2`       — lat/lon grid overlay (for geo figures)
    * `basemap/3`         — add a built-in geographic base layer
      (coastlines, borders, lunar maria)
    * `hline/3`, `vline/3`— reference lines
    * `annotate/2`        — text / arrow overlays
    * `legend/2`          — add a legend
    * `title_block/2`     — drafting title block in the corner
    * `to_svg/1`          — render

  All builder functions return the updated `%Bland.Figure{}` so you can pipe
  freely.

  ## Guides

    * [Getting started](pages/getting_started.md)
    * [Patterns and hatching](pages/patterns_and_hatching.md)
    * [Styling and themes](pages/styling_and_themes.md)
    * [Paper output](pages/paper_output.md)
    * [Showcase Livebook](notebooks/showcase.livemd)
  """

  alias Bland.{Figure, Renderer, Series, TitleBlock}

  @doc """
  Creates a new figure.

  ## Options

    * `:size` — paper preset atom or `{width, height}` tuple. Default
      `:letter_landscape`. See `Bland.Figure` for the full list.
    * `:theme` — theme preset atom or theme map. See `Bland.Theme`.
    * `:title`, `:subtitle` — figure-level text
    * `:margins` — `{top, right, bottom, left}` in px
    * All other `Bland.Figure` struct fields are also accepted.

  ## Examples

      Bland.figure(size: :a4, title: "Figure 3.2")
      Bland.figure(size: {800, 600}, theme: :blueprint)
  """
  @spec figure(keyword()) :: Figure.t()
  def figure(opts \\ []), do: Figure.new(opts)

  @doc """
  Sets axis options on a figure.

  ## Options

    * `:xlabel`, `:ylabel` — axis titles
    * `:xlim`, `:ylim` — explicit `{min, max}` or `:auto`
    * `:xscale`, `:yscale` — `:linear` (default) or `:log`
    * `:grid` — `:none`, `:major` (default), `:both`
  """
  @spec axes(Figure.t(), keyword()) :: Figure.t()
  def axes(%Figure{} = fig, opts), do: Figure.update(fig, opts)

  @doc """
  Adds a line series.

  ## Options

    * `:label` — legend text. When omitted, the series is unlabeled.
    * `:stroke` — dash preset: `:solid`, `:dashed`, `:dotted`, `:dash_dot`,
      `:long_dash`, `:fine`. Defaults cycle via `Bland.Strokes`.
    * `:stroke_width` — px override
    * `:markers` — `true` to draw markers at each data point
    * `:marker` — marker preset (see `Bland.Markers`). Defaults cycle.
    * `:marker_size` — px override

  ## Example

      Bland.line(fig, xs, ys, label: "velocity", stroke: :dashed, markers: true)
  """
  @spec line(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def line(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.Line, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds a scatter series.

  Accepts `:label`, `:marker`, `:marker_size`, `:stroke_width`.
  """
  @spec scatter(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def scatter(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.Scatter, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds a categorical bar series. `categories` and `values` must line up.

  ## Options

    * `:label` — legend text
    * `:hatch` — pattern preset (see `Bland.Patterns`). Defaults cycle.
    * `:group` — any term used to bucket bars for side-by-side grouping.
      Multiple bar series with distinct `:group` values render as a
      grouped bar chart; series sharing a group stack in the same slot.
    * `:stroke_width`

  ## Example

      cats = ["A", "B", "C"]
      Bland.bar(fig, cats, [3, 7, 2], label: "trial 1", hatch: :diagonal, group: 1)
      |> Bland.bar(cats, [5, 4, 6], label: "trial 2", hatch: :crosshatch, group: 2)
  """
  @spec bar(Figure.t(), [String.t()], [number()], keyword()) :: Figure.t()
  def bar(%Figure{} = fig, categories, values, opts \\ []) do
    Figure.add_series(fig, struct(Series.Bar,
      [categories: categories, values: values] ++ opts))
  end

  @doc """
  Adds a filled area series.

  ## Options

    * `:label`
    * `:hatch`    — fill pattern (default cycle)
    * `:baseline` — baseline y-value (default `0`)
    * `:stroke`   — outline dash preset (default `:solid`)
    * `:stroke_width`
  """
  @spec area(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def area(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.Area, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds a closed polygon series. `xs` and `ys` give the vertices; the
  renderer connects the last point back to the first.

  Unlike `area/4`, which fills down to a baseline, `polygon/4` fills
  whatever arbitrary shape the vertices describe — suitable for
  country outlines, mare boundaries, inset markers.

  ## Options

    * `:label`
    * `:hatch`  — fill pattern; `nil` (default) leaves the polygon
      stroke-only (transparent interior)
    * `:stroke` — outline dash preset (default `:solid`)
    * `:stroke_width`
  """
  @spec polygon(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def polygon(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.Polygon, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds a histogram series.

  `observations` is a raw list of numeric samples — BLAND bins them for
  you. Unlike `bar/4`, histograms render on a numeric x-axis with bars
  flush against each other at bin boundaries.

  ## Options

    * `:bins`      — bin-count strategy. Integer `N` for exactly `N`
      equal-width bins, or one of `:sturges` (default), `:sqrt`,
      `:scott`, `:freedman_diaconis`.
    * `:bin_edges` — explicit edge list; overrides `:bins`.
    * `:normalize` — how values are normalized:
        * `:count`   (default) — raw counts per bin
        * `:pmf`     — probability mass: `count / total`, `Σ = 1`
        * `:density` — density: `count / (total · width)`, ∫ = 1
        * `:cmf`     — cumulative mass: rendered as a staircase step
          line from `0` at the leftmost edge to `1` at the rightmost
    * `:density`   — shorthand for `normalize: :density`. Kept for
      backwards compatibility.
    * `:label`
    * `:hatch`     — fill pattern preset (default cycles). Ignored for
      `:cmf`, which renders as a line.
    * `:stroke`    — for `:cmf` only; dash preset for the step line
      (default `:solid`)
    * `:stroke_width`

  ## Examples

      # 20 equal-width bins, count on the y-axis
      Bland.histogram(fig, samples, bins: 20, label: "trial 1")

      # PMF — probability mass per bin
      Bland.histogram(fig, samples, bins: 30, normalize: :pmf,
        label: "Pr{X ∈ bin}")

      # Density with Scott's rule
      Bland.histogram(fig, samples, bins: :scott, normalize: :density)

      # Empirical CDF — renders as a staircase line, not bars
      Bland.histogram(fig, samples, bins: 50, normalize: :cmf,
        label: "F(x)")

      # Explicit edges — useful for apples-to-apples comparison across
      # two datasets
      Bland.histogram(fig, samples_a,
        bin_edges: Enum.map(0..10, &(&1 * 1.0)), label: "A")

  See `Bland.Histogram` for the underlying binning helpers.
  """
  @spec histogram(Figure.t(), [number()], keyword()) :: Figure.t()
  def histogram(%Figure{} = fig, observations, opts \\ []) when is_list(observations) do
    bin_opts = Keyword.take(opts, [:bins, :bin_edges, :density, :normalize])
    {edges, values, mode} = Bland.Histogram.bin(observations, bin_opts)
    remaining = Keyword.drop(opts, [:bins, :bin_edges, :density, :normalize, :hatch])

    case mode do
      :cmf ->
        {xs, ys} = Bland.Histogram.staircase(edges, values)
        line_opts = Keyword.drop(remaining, [:stroke_width]) ++
                      [stroke_width: Keyword.get(remaining, :stroke_width, nil)]
        line(fig, xs, ys, line_opts |> Enum.reject(fn {_k, v} -> is_nil(v) end))

      _bars ->
        hatch = Keyword.get(opts, :hatch)
        density? = mode == :density

        series =
          struct(Series.Histogram,
            [
              bin_edges: edges,
              values: values,
              normalize: mode,
              density: density?,
              hatch: hatch
            ] ++ remaining
          )

        Figure.add_series(fig, series)
    end
  end

  @doc """
  Adds a heatmap series.

  `grid` is a 2D list (`rows x cols`) of numeric values. Each cell is
  quantized to one of `N` levels and filled with the corresponding
  pattern from the ramp.

  ## Options

    * `:x_edges` — list of length `cols + 1` giving column boundaries
      in data space. Defaults to `0..cols`.
    * `:y_edges` — list of length `rows + 1` giving row boundaries.
      Defaults to `0..rows`.
    * `:ramp`    — list of pattern preset atoms, light → dark. Defaults
      to `Bland.Heatmap.default_ramp/0` (7 levels).
    * `:range`   — `{lo, hi}` for quantization. Defaults to `:auto`
      (min/max of the data).
    * `:origin`  — `:bottom_left` (default, Cartesian) or `:top_left`
      (matrix-style; row 0 renders at the top).
    * `:label`   — label for the colorbar entry.

  ## Examples

      # 20 × 20 grid of a 2D Gaussian
      grid =
        for j <- -10..9, into: [] do
          for i <- -10..9, into: [] do
            :math.exp(-(i * i + j * j) / 40)
          end
        end

      Bland.figure(size: :square, title: "2D Gaussian")
      |> Bland.axes(xlabel: "x", ylabel: "y")
      |> Bland.heatmap(grid,
           x_edges: Enum.map(-10..10, &(&1 * 1.0)),
           y_edges: Enum.map(-10..10, &(&1 * 1.0)),
           label: "density")
      |> Bland.colorbar()
      |> Bland.to_svg()

  See `Bland.Heatmap` for the underlying ramp/quantize helpers.
  """
  @spec heatmap(Figure.t(), [[number()]], keyword()) :: Figure.t()
  def heatmap(%Figure{} = fig, grid, opts \\ []) when is_list(grid) do
    rows = length(grid)
    cols = if rows > 0, do: length(List.first(grid)), else: 0

    x_edges = Keyword.get(opts, :x_edges, Enum.map(0..cols, &(&1 * 1.0)))
    y_edges = Keyword.get(opts, :y_edges, Enum.map(0..rows, &(&1 * 1.0)))

    remaining = Keyword.drop(opts, [:x_edges, :y_edges])

    series =
      struct(Series.Heatmap,
        [data: grid, x_edges: x_edges, y_edges: y_edges] ++ remaining
      )

    Figure.add_series(fig, series)
  end

  @doc """
  Attaches a colorbar (ramp legend) to the figure.

  By default the colorbar describes the *last* heatmap added. You may
  also pass an explicit `series:` index or a `ramp:` and `range:`
  directly for standalone ramps.

  ## Options

    * `:position` — `:right` (default), `:left`, `:bottom`, or a
      `{px, py}` tuple.
    * `:label`    — axis label for the ramp; defaults to the heatmap's
      `:label`.
    * `:ramp`     — override the ramp (otherwise inherited from the
      heatmap series).
    * `:range`    — override the `{lo, hi}` bounds shown on the ramp.
    * `:levels`   — number of tick marks on the ramp (default 5).
  """
  @spec colorbar(Figure.t(), keyword()) :: Figure.t()
  def colorbar(%Figure{} = fig, opts \\ []) do
    %{fig | colorbar: Map.new(opts)}
  end

  @doc """
  Adds a latitude/longitude graticule as a series of dotted reference
  lines. Only meaningful on figures with `projection: :mercator` or
  `:equirect`.

  ## Options

    * `:lon_step`  (default `30`) — meridian spacing in degrees
    * `:lat_step`  (default `30`) — parallel spacing in degrees
    * `:lon_range` (default `{-180, 180}`)
    * `:lat_range` (default `{-80, 80}`)
    * `:stroke`    (default `:dotted`)
    * `:labels`    (default `true`) — annotate each line with its
      lat/lon value
    * `:label_position` — `:lon_edge | :plot_edge | :none`
      (default `:lon_edge`: meridians label at the equator, parallels
      label at the western lon bound)

  ## Example

      Bland.figure(size: :a4_landscape, projection: :mercator)
      |> Bland.graticule(lon_step: 30, lat_step: 20)
      |> Bland.line(coast_lons, coast_lats, stroke: :solid)
      |> Bland.to_svg()
  """
  @spec graticule(Figure.t(), keyword()) :: Figure.t()
  def graticule(%Figure{} = fig, opts \\ []) do
    stroke = Keyword.get(opts, :stroke, :dotted)
    labels? = Keyword.get(opts, :labels, true)
    label_pos = Keyword.get(opts, :label_position, :lon_edge)

    lon_step = Keyword.get(opts, :lon_step, 30)
    lat_step = Keyword.get(opts, :lat_step, 30)
    {lat_lo, lat_hi} = Keyword.get(opts, :lat_range, {-80, 80})
    {lon_lo, lon_hi} = Keyword.get(opts, :lon_range, {-180, 180})
    samples = Keyword.get(opts, :samples, 60)

    graticule_lines =
      Bland.Geo.graticule(
        lon_step: lon_step,
        lat_step: lat_step,
        lon_range: {lon_lo, lon_hi},
        lat_range: {lat_lo, lat_hi},
        samples: samples
      )

    fig_with_lines =
      Enum.reduce(graticule_lines, fig, fn {xs, ys}, acc ->
        line(acc, xs, ys, stroke: stroke, stroke_width: 0.5)
      end)

    if labels? do
      graticule_labels(fig_with_lines, label_pos,
        lon_step: lon_step,
        lat_step: lat_step,
        lon_range: {lon_lo, lon_hi},
        lat_range: {lat_lo, lat_hi}
      )
    else
      fig_with_lines
    end
  end

  defp graticule_labels(fig, :none, _opts), do: fig

  defp graticule_labels(fig, pos, opts) do
    lon_step = opts[:lon_step]
    lat_step = opts[:lat_step]
    {lat_lo, lat_hi} = opts[:lat_range]
    {lon_lo, lon_hi} = opts[:lon_range]

    label_lat =
      case pos do
        :lon_edge -> 0.0
        :plot_edge -> lat_lo * 1.0
      end

    label_lon =
      case pos do
        :lon_edge -> lon_lo * 1.0
        :plot_edge -> lon_lo * 1.0
      end

    meridian_labels =
      Enum.map(arange(lon_lo, lon_hi, lon_step), fn lon ->
        %{type: :text, x: lon * 1.0, y: label_lat, text: format_lon(lon),
          anchor: "middle", font_size: 8}
      end)

    parallel_labels =
      Enum.map(arange(lat_lo, lat_hi, lat_step), fn lat ->
        %{type: :text, x: label_lon, y: lat * 1.0, text: format_lat(lat),
          anchor: "start", font_size: 8}
      end)

    %{fig | annotations: fig.annotations ++ meridian_labels ++ parallel_labels}
  end

  defp arange(lo, hi, step) do
    n = trunc((hi - lo) / step)
    Enum.map(0..n, fn i -> lo + i * step end)
  end

  defp format_lon(0), do: "0°"
  defp format_lon(lon) when lon > 0, do: "#{trunc(lon)}°E"
  defp format_lon(lon), do: "#{trunc(-lon)}°W"

  defp format_lat(0), do: "0°"
  defp format_lat(lat) when lat > 0, do: "#{trunc(lat)}°N"
  defp format_lat(lat), do: "#{trunc(-lat)}°S"

  @doc """
  Adds a built-in geographic base layer to the figure.

  See `Bland.Basemaps` for the available layers. Typical usage:

      Bland.figure(size: :a4_landscape, projection: :mercator,
        xlim: {-180, 180}, ylim: {-70, 75})
      |> Bland.basemap(:earth_coastlines)
      |> Bland.basemap(:earth_borders, stroke: :dashed)
      |> Bland.basemap(:earth_tropics, stroke: :dotted)

      # Lunar plate
      Bland.figure(size: :square, projection: :equirect,
        xlim: {-90, 90}, ylim: {-60, 60})
      |> Bland.basemap(:moon_maria, hatch: :dots_sparse)

  ## Options

    * `:resolution`   — for `:earth_coastlines` and `:earth_borders`,
      selects which vendored Natural Earth dataset to load:
      `:low` (1:110m, default), `:high` (1:50m), or `:schematic`
      (the hand-drawn outlines shipped with BLAND 0.1).
    * `:stroke`       — line-dash preset for open features / outlines
      (default `:solid`)
    * `:stroke_width` — override stroke weight
    * `:hatch`        — for closed features, fill with this pattern
      instead of leaving the interior transparent. Ignored on open
      features like `:earth_tropics`.
    * `:only`         — list of feature names to include (filters the
      layer's built-in feature set)
    * `:except`       — list of feature names to exclude

  ## Examples

      # High-res countries, filled with a light hatch
      Bland.basemap(fig, :earth_borders, resolution: :high,
        stroke: :solid, stroke_width: 0.4)

      # Only draw a few named countries
      Bland.basemap(fig, :earth_borders,
        only: ["United States of America", "Canada", "Mexico"])

      # Fill lunar maria with a hatched pattern
      Bland.basemap(fig, :moon_maria, hatch: :diagonal)
  """
  @spec basemap(Figure.t(), Bland.Basemaps.layer(), keyword()) :: Figure.t()
  def basemap(%Figure{} = fig, layer, opts \\ []) do
    resolution = Keyword.get(opts, :resolution, :low)

    features =
      Bland.Basemaps.features(layer, resolution)
      |> filter_features(opts)

    stroke = Keyword.get(opts, :stroke, :solid)
    stroke_width = Keyword.get(opts, :stroke_width, 0.8)
    hatch = Keyword.get(opts, :hatch)

    Enum.reduce(features, fig, fn feature, acc ->
      {lons, lats} = Bland.Basemaps.unzip(feature)

      cond do
        feature.closed? and not is_nil(hatch) ->
          polygon(acc, lons, lats,
            hatch: hatch,
            stroke: stroke,
            stroke_width: stroke_width
          )

        feature.closed? ->
          polygon(acc, lons, lats,
            hatch: nil,
            stroke: stroke,
            stroke_width: stroke_width
          )

        true ->
          line(acc, lons, lats, stroke: stroke, stroke_width: stroke_width)
      end
    end)
  end

  defp filter_features(features, opts) do
    features
    |> maybe_filter(:only, opts, fn f, names -> f.name in names end)
    |> maybe_filter(:except, opts, fn f, names -> f.name not in names end)
  end

  defp maybe_filter(features, key, opts, pred) do
    case Keyword.get(opts, key) do
      nil -> features
      names when is_list(names) -> Enum.filter(features, &pred.(&1, names))
    end
  end

  @doc """
  Adds a horizontal reference line at y-value `y`.

  Options: `:label`, `:stroke` (default `:dashed`), `:stroke_width`.
  """
  @spec hline(Figure.t(), number(), keyword()) :: Figure.t()
  def hline(%Figure{} = fig, y, opts \\ []) do
    Figure.add_series(fig, struct(Series.Hline, [y: y] ++ opts))
  end

  @doc """
  Adds a vertical reference line at x-value `x`.

  Options: `:label`, `:stroke` (default `:dashed`), `:stroke_width`.
  """
  @spec vline(Figure.t(), number(), keyword()) :: Figure.t()
  def vline(%Figure{} = fig, x, opts \\ []) do
    Figure.add_series(fig, struct(Series.Vline, [x: x] ++ opts))
  end

  @doc """
  Adds an annotation overlay.

  ## Supported shapes

    * `text: "…", at: {x, y}` — text at data-space coordinates. Accepts
      `:font_size` and `:anchor` (`"start"` / `"middle"` / `"end"`).
    * `arrow: {from_xy, to_xy}` — straight arrow between two data points.

  ## Example

      fig
      |> Bland.annotate(text: "peak", at: {3.7, 0.92})
      |> Bland.annotate(arrow: {{3.5, 0.85}, {3.7, 0.92}})
  """
  @spec annotate(Figure.t(), keyword()) :: Figure.t()
  def annotate(%Figure{annotations: list} = fig, opts) do
    case opts do
      [{:text, text} | rest] ->
        {x, y} = Keyword.fetch!(rest, :at)

        ann =
          Map.merge(%{type: :text, x: x, y: y, text: text}, Map.new(Keyword.delete(rest, :at)))

        %{fig | annotations: list ++ [ann]}

      [{:arrow, {from, to}} | _] ->
        %{fig | annotations: list ++ [%{type: :arrow, from: from, to: to}]}

      _ ->
        raise ArgumentError,
              "annotate/2 expects `text: ..., at: {x, y}` or `arrow: {{x,y},{x,y}}`; got #{inspect(opts)}"
    end
  end

  @doc """
  Attaches (or replaces) a legend on the figure.

  ## Options

    * `:position` — `:top_right` (default), `:top_left`, `:bottom_right`,
      `:bottom_left`, or a `{px, py}` tuple for manual placement.
    * `:title` — optional bold heading above the entries.
  """
  @spec legend(Figure.t(), keyword()) :: Figure.t()
  def legend(%Figure{} = fig, opts \\ []) do
    %{fig | legend: Map.new(opts)}
  end

  @doc """
  Attaches (or replaces) a drafting title block. See `Bland.TitleBlock` for
  the full field list.
  """
  @spec title_block(Figure.t(), keyword()) :: Figure.t()
  def title_block(%Figure{} = fig, opts) do
    %{fig | title_block: TitleBlock.new(opts)}
  end

  @doc """
  Renders a figure to an SVG string.
  """
  @spec to_svg(Figure.t()) :: String.t()
  def to_svg(%Figure{} = fig), do: Renderer.to_svg(fig)

  @doc """
  Renders a figure and writes it to `path`.
  """
  @spec write!(Figure.t(), Path.t()) :: :ok
  def write!(%Figure{} = fig, path) do
    File.write!(path, to_svg(fig))
  end

  @doc """
  Shortcut for rendering + Livebook inline display.

  In Livebook, `Kino.Image.new/2` expects a binary and a MIME type. If
  `:kino` is not installed, call `to_svg/1` and wrap the result yourself.
  """
  @spec to_kino(Figure.t()) :: any()
  def to_kino(%Figure{} = fig) do
    svg = to_svg(fig)

    if Code.ensure_loaded?(Kino.Image) do
      apply(Kino.Image, :new, [svg, "image/svg+xml"])
    else
      raise """
      Bland.to_kino/1 requires :kino. In a Livebook cell, add:

          Mix.install([{:bland, path: "…"}, :kino])
      """
    end
  end
end
