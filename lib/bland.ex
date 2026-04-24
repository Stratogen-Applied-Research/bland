defmodule Bland do
  @moduledoc """
  **BLAND — Elixir Technical Drawing.**

  ![Damped oscillation — hero figure with title block](assets/hero_title_block.svg)

  A pure-Elixir library for producing monochrome, paper-ready plots in the
  visual tradition of 1960s–1980s engineering reports: thin black rules,
  serif type, crisp frames, hatched fills, and optional drafting title
  blocks.

  BLAND emits SVG. SVG is the right format for paper output — resolution-
  independent, prints clean on any printer, and embeds into Livebook, PDF
  pipelines, and LaTeX figures without conversion.

  See the [gallery](gallery.md) for every plot type at a glance.

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
  Creates a polar figure.

  Series data on the returned figure is interpreted as `{θ, r}` pairs
  (θ in radians). The renderer projects every point through
  `(θ, r) → (r·cos θ, r·sin θ)`, clips to the disk of radius `rmax`,
  and suppresses the default x/y axes.

  Pair with `polar_grid/2` to add the concentric / radial reference
  grid:

      Bland.polar_figure(rmax: 1.0, title: "Antenna gain")
      |> Bland.polar_grid(r_ticks: [0.25, 0.5, 0.75, 1.0])
      |> Bland.line(thetas, gains)

  ## Options

    * `:rmax`  — radius of the plotting disk in data units (default `1.0`)
    * `:size`  — canvas size; defaults to `:square` for equal aspect
    * Any other figure option (`:title`, `:theme`, etc.) is forwarded.
  """
  @spec polar_figure(keyword()) :: Figure.t()
  def polar_figure(opts \\ []) do
    rmax = Keyword.get(opts, :rmax, 1.0)
    size = Keyword.get(opts, :size, :square)

    defaults = [
      size: size,
      projection: :polar,
      xlim: {-rmax, rmax},
      ylim: {-rmax, rmax},
      grid: :none,
      clip: :circle,
      axes: :none
    ]

    figure(Keyword.merge(defaults, Keyword.drop(opts, [:rmax])))
  end

  @doc """
  Adds a polar reference grid to a figure built via `polar_figure/1`.

  Produces concentric circles at the requested radii and radial lines
  at the requested angles, plus perimeter labels for the angles.

  ## Options

    * `:r_ticks`       — list of radii (default: four evenly-spaced
      steps ending at `rmax`)
    * `:theta_step`    — angle between radial lines, in degrees
      (default `30`)
    * `:stroke`        — dash preset for the grid lines (default `:dotted`)
    * `:stroke_width`  — grid line weight (default `0.4`)
    * `:labels`        — `true` (default) to annotate each angular
      direction at the perimeter
    * `:r_labels`      — `true` to annotate each radius on the 0° ray
      (default `false`)
    * `:samples`       — points per circle (default `120`)
  """
  @spec polar_grid(Figure.t(), keyword()) :: Figure.t()
  def polar_grid(%Figure{xlim: {xlo, xhi}} = fig, opts \\ []) do
    rmax = max(abs(xlo), abs(xhi)) * 1.0

    r_ticks = Keyword.get(opts, :r_ticks, default_r_ticks(rmax))
    theta_step_deg = Keyword.get(opts, :theta_step, 30)
    stroke = Keyword.get(opts, :stroke, :dotted)
    sw = Keyword.get(opts, :stroke_width, 0.4)
    samples = Keyword.get(opts, :samples, 120)
    with_labels? = Keyword.get(opts, :labels, true)
    with_r_labels? = Keyword.get(opts, :r_labels, false)

    theta_ticks_deg = Enum.to_list(0..(360 - theta_step_deg)//theta_step_deg)
    theta_ticks = Enum.map(theta_ticks_deg, &(&1 * :math.pi() / 180))

    fig =
      Enum.reduce(r_ticks, fig, fn r, acc ->
        {thetas, rs} = Bland.Polar.circle(r, samples)
        line(acc, thetas, rs, stroke: stroke, stroke_width: sw)
      end)

    fig =
      Enum.reduce(theta_ticks, fig, fn theta, acc ->
        line(acc, [theta, theta], [0.0, rmax], stroke: stroke, stroke_width: sw)
      end)

    fig =
      if with_labels? do
        label_radius = rmax * 1.07

        Enum.zip(theta_ticks, theta_ticks_deg)
        |> Enum.reduce(fig, fn {theta, deg}, acc ->
          annotate(acc,
            text: "#{deg}°",
            at: {theta, label_radius},
            anchor: "middle",
            font_size: 9
          )
        end)
      else
        fig
      end

    if with_r_labels? do
      Enum.reduce(r_ticks, fig, fn r, acc ->
        annotate(acc, text: Bland.Ticks.format(r), at: {0.0, r},
          anchor: "start", font_size: 8)
      end)
    else
      fig
    end
  end

  defp default_r_ticks(rmax) do
    step = rmax / 4
    Enum.map(1..4, fn i -> i * step end)
  end

  @doc """
  Creates a Smith chart figure — a unit-disk canvas for plotting
  reflection coefficients `Γ` in RF / microwave work.

  The returned figure has no standard axes, a circular clip to `|Γ|
  ≤ 1`, and a square canvas. Pair with `smith_grid/2` for the
  classical grid of constant-resistance circles and constant-reactance
  arcs.

      Bland.smith_figure(title: "S₁₁")
      |> Bland.smith_grid()
      |> Bland.line(gamma_real, gamma_imag, label: "sweep")

  Convert impedance values to Γ via `Bland.Smith.gamma_from_z/1`.

  ## Options

    * `:size` — canvas size; defaults to `:square`
    * All other figure options are forwarded.
  """
  @spec smith_figure(keyword()) :: Figure.t()
  def smith_figure(opts \\ []) do
    size = Keyword.get(opts, :size, :square)

    defaults = [
      size: size,
      xlim: {-1.08, 1.08},
      ylim: {-1.08, 1.08},
      grid: :none,
      clip: :circle,
      axes: :none
    ]

    figure(Keyword.merge(defaults, opts))
  end

  @doc """
  Adds the classical Smith chart grid to a figure: constant-resistance
  circles (`r = 0.2, 0.5, 1, 2, 5` by default), constant-reactance arcs
  (at `±0.2, ±0.5, ±1, ±2, ±5`), plus the unit circle boundary and the
  real axis.

  ## Options

    * `:r_values`     — list of normalized resistances for the
      R-circles (default `Bland.Smith.default_r_values/0`)
    * `:x_values`     — list of normalized reactance magnitudes;
      each also draws its negative counterpart
      (default `Bland.Smith.default_x_values/0`)
    * `:stroke`       — grid dash preset (default `:dotted`)
    * `:stroke_width` — (default `0.4`)
    * `:boundary_stroke_width` — weight of the unit circle and real
      axis (default `0.8`)
    * `:labels`       — `true` to annotate each R circle and X arc
      (default `true`)
    * `:samples`      — points per circle (default `120`)
  """
  @spec smith_grid(Figure.t(), keyword()) :: Figure.t()
  def smith_grid(%Figure{} = fig, opts \\ []) do
    r_values = Keyword.get(opts, :r_values, Bland.Smith.default_r_values())
    x_values = Keyword.get(opts, :x_values, Bland.Smith.default_x_values())
    stroke = Keyword.get(opts, :stroke, :dotted)
    sw = Keyword.get(opts, :stroke_width, 0.4)
    boundary_sw = Keyword.get(opts, :boundary_stroke_width, 0.8)
    samples = Keyword.get(opts, :samples, 120)
    with_labels? = Keyword.get(opts, :labels, true)

    # Unit circle boundary (|Γ| = 1)
    {ubx, uby} = trace_unit_circle(samples)
    fig = line(fig, ubx, uby, stroke: :solid, stroke_width: boundary_sw)

    # Real axis inside the disk (horizontal line)
    fig = line(fig, [-1.0, 1.0], [0.0, 0.0], stroke: :solid, stroke_width: boundary_sw)

    # Constant-R circles
    fig =
      Enum.reduce(r_values, fig, fn r, acc ->
        {xs, ys} = Bland.Smith.r_circle(r, samples)
        line(acc, xs, ys, stroke: stroke, stroke_width: sw)
      end)

    # Constant-X arcs (both ± signs). The clip handles the non-disk portions.
    fig =
      Enum.reduce(x_values, fig, fn x_mag, acc ->
        {xs_pos, ys_pos} = Bland.Smith.x_arc(x_mag, samples)
        {xs_neg, ys_neg} = Bland.Smith.x_arc(-x_mag, samples)

        acc
        |> line(xs_pos, ys_pos, stroke: stroke, stroke_width: sw)
        |> line(xs_neg, ys_neg, stroke: stroke, stroke_width: sw)
      end)

    if with_labels?, do: add_smith_labels(fig, r_values, x_values), else: fig
  end

  defp trace_unit_circle(n) do
    step = 2 * :math.pi() / n

    Enum.map(0..n, fn i ->
      phi = i * step
      {:math.cos(phi), :math.sin(phi)}
    end)
    |> Enum.unzip()
  end

  defp add_smith_labels(fig, r_values, x_values) do
    # R labels: where each R-circle meets the real axis (right side).
    # On a constant-R circle with center (r/(r+1), 0), the right-most
    # point is (r/(r+1) + 1/(r+1), 0) = (1, 0) for all R — not useful.
    # The LEFT-most point is ((r-1)/(r+1), 0), which is distinct.
    fig =
      Enum.reduce(r_values, fig, fn r, acc ->
        x_pos = (r - 1) / (r + 1)

        annotate(acc,
          text: Bland.Ticks.format(r),
          at: {x_pos, 0.0},
          anchor: "middle",
          font_size: 7
        )
      end)

    # X labels: place at the top/bottom of each X-arc's intersection
    # with the unit circle. For X = x_mag, the unit-circle intersection
    # other than (1, 0) is:
    #   Γ_re = (x² - 1)/(x² + 1), Γ_im = 2x/(x² + 1)
    Enum.reduce(x_values, fig, fn x_mag, acc ->
      denom = x_mag * x_mag + 1
      gre = (x_mag * x_mag - 1) / denom
      gim_top = 2 * x_mag / denom
      gim_bot = -gim_top

      acc
      |> annotate(text: "+#{Bland.Ticks.format(x_mag)}",
           at: {gre, gim_top * 1.05},
           anchor: "middle", font_size: 7)
      |> annotate(text: "−#{Bland.Ticks.format(x_mag)}",
           at: {gre, gim_bot * 1.05},
           anchor: "middle", font_size: 7)
    end)
  end

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
  Adds an error-bar series — data points with X and/or Y uncertainty
  whiskers.

  `yerr`/`xerr` accept either a list of symmetric half-widths or a list
  of `{lower, upper}` tuples for asymmetric error.

  ## Options

    * `:yerr`       — symmetric or asymmetric y-error per point
    * `:xerr`       — same for x
    * `:marker`     — marker at each point (default `:circle_filled`;
      set `nil` to suppress)
    * `:marker_size`, `:cap_width`, `:stroke_width`, `:label`

  ## Examples

      Bland.errorbar(fig, xs, ys, yerr: sigmas, label: "±1σ")
      Bland.errorbar(fig, xs, ys, yerr: Enum.zip(lower, upper))
      Bland.errorbar(fig, xs, ys, yerr: yerr, xerr: xerr)
  """
  @spec errorbar(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def errorbar(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.ErrorBar, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds a box-and-whisker summary. `categories_and_samples` pairs each
  category label with a list of raw observations; BLAND computes the
  quartiles, Tukey-fence whiskers, and outliers for you via
  `Bland.Stats.boxplot_stats/2`.

  ## Options

    * `:label`      — legend text
    * `:hatch`      — IQR box fill (default cycles)
    * `:box_width`  — width fraction of the category slot (default `0.6`)
    * `:stroke_width`

  ## Example

      Bland.boxplot(fig, [
        {"control", control_samples},
        {"treated", treated_samples}
      ], label: "distribution")
  """
  @spec boxplot(Figure.t(), [{String.t(), [number()]}], keyword()) :: Figure.t()
  def boxplot(%Figure{} = fig, categories_and_samples, opts \\ []) do
    {cats, samples_lists} = Enum.unzip(categories_and_samples)
    stats = Enum.map(samples_lists, &Bland.Stats.boxplot_stats/1)

    Figure.add_series(fig, struct(Series.BoxPlot,
      [categories: cats, stats: stats] ++ opts
    ))
  end

  @doc """
  Adds a stem-plot series — the discrete-signal staple from DSP.

  Each point renders as a vertical line from `:baseline` (default `0`)
  up to `(x, y)`, with a marker at the tip.

  ## Options

    * `:baseline`, `:marker` (default `:circle_filled`), `:marker_size`,
      `:stroke`, `:stroke_width`, `:label`
  """
  @spec stem(Figure.t(), [number()], [number()], keyword()) :: Figure.t()
  def stem(%Figure{} = fig, xs, ys, opts \\ []) do
    Figure.add_series(fig, struct(Series.Stem, [xs: xs, ys: ys] ++ opts))
  end

  @doc """
  Adds contour (iso-level) curves over a 2D scalar grid.

  ## Options

    * `:levels`  — list of scalar values at which to draw contours
      (default: 7 evenly-spaced levels across the data range)
    * `:x_edges`, `:y_edges` — cell boundaries (default `0..cols`, `0..rows`)
    * `:origin`  — `:bottom_left` (default) or `:top_left`
    * `:stroke`  — dash preset (default `:solid`). Negative levels
      render dashed automatically to convey sign.
    * `:stroke_width`, `:label`

  ## Example

      grid =
        for j <- -20..20, do: (for i <- -20..20, do: :math.sin(i * 0.2) * :math.cos(j * 0.2))

      Bland.contour(fig, grid,
        x_edges: Enum.map(-20..21, &(&1 * 0.1)),
        y_edges: Enum.map(-20..21, &(&1 * 0.1)),
        levels: [-0.8, -0.4, 0, 0.4, 0.8])
  """
  @spec contour(Figure.t(), [[number()]], keyword()) :: Figure.t()
  def contour(%Figure{} = fig, grid, opts \\ []) when is_list(grid) do
    rows = length(grid)
    cols = if rows > 0, do: length(List.first(grid)), else: 0

    x_edges = Keyword.get(opts, :x_edges, Enum.map(0..cols, &(&1 * 1.0)))
    y_edges = Keyword.get(opts, :y_edges, Enum.map(0..rows, &(&1 * 1.0)))
    levels = Keyword.get(opts, :levels, default_contour_levels(grid))
    remaining = Keyword.drop(opts, [:x_edges, :y_edges, :levels])

    Figure.add_series(fig, struct(Series.Contour,
      [data: grid, x_edges: x_edges, y_edges: y_edges, levels: levels] ++ remaining
    ))
  end

  defp default_contour_levels(grid) do
    {lo, hi} = Bland.Heatmap.extent(grid)
    step = (hi - lo) / 8
    Enum.map(1..7, fn i -> lo + i * step end)
  end

  @doc """
  Adds a vector-field (quiver) series. Each `(xs[i], ys[i])` gets an
  arrow with components `(us[i], vs[i])`.

  ## Options

    * `:scale`     — multiply each vector before drawing (default `1.0`)
    * `:head_size` — arrow-head pixel length (default `6`)
    * `:stroke`, `:stroke_width`, `:label`
  """
  @spec quiver(Figure.t(), [number()], [number()], [number()], [number()], keyword()) ::
          Figure.t()
  def quiver(%Figure{} = fig, xs, ys, us, vs, opts \\ []) do
    Figure.add_series(fig, struct(Series.Quiver,
      [xs: xs, ys: ys, us: us, vs: vs] ++ opts
    ))
  end

  @doc """
  Adds a Q-Q (quantile-quantile) plot — sample quantiles vs theoretical
  quantiles of a named distribution, with a `y = x` reference line.

  ## Options

    * `:distribution` — `:normal` (default). Other distributions can
      be added later.
    * `:reference`    — `true` (default) to draw the y=x reference line
    * `:marker`       — default `:circle_open`
    * `:marker_size`, `:label`

  ## Example

      Bland.qq_plot(fig, samples, label: "residuals")
  """
  @spec qq_plot(Figure.t(), [number()], keyword()) :: Figure.t()
  def qq_plot(%Figure{} = fig, samples, opts \\ []) do
    dist = Keyword.get(opts, :distribution, :normal)
    ref? = Keyword.get(opts, :reference, true)
    marker = Keyword.get(opts, :marker, :circle_open)
    remaining = Keyword.drop(opts, [:distribution, :reference, :marker])

    sorted = Enum.sort(samples)
    n = length(sorted)

    theoretical =
      Enum.map(1..n, fn k ->
        p = (k - 0.5) / n
        theoretical_quantile(dist, p)
      end)

    fig =
      scatter(fig, theoretical, sorted,
        [marker: marker] ++ remaining
      )

    if ref? do
      {lo, hi} = Enum.min_max(theoretical ++ sorted)
      line(fig, [lo, hi], [lo, hi], stroke: :dashed)
    else
      fig
    end
  end

  defp theoretical_quantile(:normal, p), do: Bland.Stats.normal_quantile(p)

  defp theoretical_quantile(other, _),
    do: raise(ArgumentError, "unsupported distribution #{inspect(other)}")

  @doc """
  Renders a Bode plot — magnitude (dB, log-linear) on top, phase
  (degrees, log-linear) on the bottom — as a two-panel SVG.

  `omegas` is a list of angular frequencies (or just frequencies — they
  just become x-coordinates on a log axis). Pass either:

    * Pre-computed `{mag_db, phase_deg}` lists, OR
    * A transfer-function callback `fn ω -> {real, imag} end` returning
      the complex value of `H(jω)` at each frequency.

  Returns an SVG binary ready to write or embed.

  ## Options

    * `:cell_width`, `:cell_height` — per-panel size
    * `:title`                      — outer title
    * `:xlabel`                     — frequency axis label (default `"ω"`)
    * `:mag_label`                  — magnitude y-axis label (default `"|H| [dB]"`)
    * `:phase_label`                — phase y-axis label (default `"∠H [°]"`)
    * `:theme`                      — passed through to both panels

  ## Examples

      # From precomputed magnitude and phase
      Bland.bode(omegas, mag_db, phase_deg)

      # From a transfer-function callback: H(s) = 1 / (1 + s/10) evaluated
      # at s = jω
      Bland.bode(omegas, fn omega ->
        {1 / (1 + omega * omega / 100), -omega / (10 + omega * omega / 10)}
      end)
  """
  @spec bode([number()], [number()] | function(), [number()] | keyword(), keyword()) ::
          String.t()
  def bode(omegas, mag_or_tf, phase_or_opts \\ [], opts \\ [])

  def bode(omegas, tf, opts, _extra) when is_function(tf, 1) do
    {mags_db, phases_deg} =
      omegas
      |> Enum.map(fn w ->
        {re, im} = tf.(w)
        mag = :math.sqrt(re * re + im * im)
        mag_db = 20 * :math.log10(max(mag, 1.0e-300))
        phase_deg = :math.atan2(im, re) * 180 / :math.pi()
        {mag_db, phase_deg}
      end)
      |> Enum.unzip()

    build_bode_grid(omegas, mags_db, phases_deg, opts)
  end

  def bode(omegas, mag_db, phase_deg, opts)
      when is_list(mag_db) and is_list(phase_deg) do
    build_bode_grid(omegas, mag_db, phase_deg, opts)
  end

  defp build_bode_grid(omegas, mag_db, phase_deg, opts) do
    xlabel = Keyword.get(opts, :xlabel, "ω")
    mag_label = Keyword.get(opts, :mag_label, "|H| [dB]")
    phase_label = Keyword.get(opts, :phase_label, "∠H [°]")
    title = Keyword.get(opts, :title)
    cell_w = Keyword.get(opts, :cell_width, 900)
    cell_h = Keyword.get(opts, :cell_height, 320)
    theme = Keyword.get(opts, :theme, :report_1972)

    xlim = {Enum.min(omegas), Enum.max(omegas)}

    mag_fig =
      figure(size: {cell_w, cell_h}, theme: theme, title: title)
      |> axes(xlabel: xlabel, ylabel: mag_label, xscale: :log, xlim: xlim)
      |> line(omegas, mag_db)

    phase_fig =
      figure(size: {cell_w, cell_h}, theme: theme)
      |> axes(xlabel: xlabel, ylabel: phase_label, xscale: :log, xlim: xlim)
      |> line(omegas, phase_deg)

    grid([mag_fig, phase_fig],
      columns: 1,
      cell_width: cell_w,
      cell_height: cell_h,
      title: nil
    )
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
  Composes a list of figures into a single SVG with a grid layout.

  This is how you build multi-panel figures — Bode plots, dashboards,
  before/after comparisons — while getting a single printable SVG at
  the end. Each panel renders independently: its own ticks, labels,
  legend, ornaments.

  See `Bland.Grid` for the full option list. Common options:

    * `:columns`, `:rows` — grid shape
    * `:cell_width`, `:cell_height` — pixel size of each cell
    * `:gap`, `:padding` — spacing
    * `:title` — outer title across all panels

  ## Example

      a = Bland.figure(title: "Before") |> Bland.line(xs, ys1)
      b = Bland.figure(title: "After")  |> Bland.line(xs, ys2)

      svg = Bland.grid([a, b], columns: 2, title: "Comparison")
  """
  @spec grid([Figure.t()], keyword()) :: String.t()
  def grid(figures, opts \\ []), do: Bland.Grid.render(figures, opts)

  @doc """
  Like `grid/2`, but returns a `Kino.Image` for Livebook inline
  display.
  """
  @spec grid_to_kino([Figure.t()], keyword()) :: any()
  def grid_to_kino(figures, opts \\ []) do
    svg = grid(figures, opts)

    if Code.ensure_loaded?(Kino.Image) do
      apply(Kino.Image, :new, [svg, "image/svg+xml"])
    else
      raise "Bland.grid_to_kino/2 requires :kino"
    end
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
