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
    * `area/4`            — filled region with hatched fill
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
  Adds a histogram series.

  `observations` is a raw list of numeric samples — BLAND bins them for
  you. Unlike `bar/4`, histograms render on a numeric x-axis with bars
  flush against each other at bin boundaries.

  ## Options

    * `:bins`      — bin-count strategy. Integer `N` for exactly `N`
      equal-width bins, or one of `:sturges` (default), `:sqrt`,
      `:scott`, `:freedman_diaconis`.
    * `:bin_edges` — explicit edge list; overrides `:bins`.
    * `:density`   — `true` to render densities (area sums to 1)
      instead of raw counts. Default `false`.
    * `:label`
    * `:hatch`     — fill pattern preset (default cycles)
    * `:stroke_width`

  ## Examples

      # 20 equal-width bins, count on the y-axis
      Bland.histogram(fig, samples, bins: 20, label: "trial 1")

      # Density with Scott's rule
      Bland.histogram(fig, samples, bins: :scott, density: true)

      # Explicit edges — useful for apples-to-apples comparison across
      # two datasets
      Bland.histogram(fig, samples_a, bin_edges: Enum.map(0..10, &(&1 * 1.0)),
        label: "A")

  See `Bland.Histogram` for the underlying binning helpers.
  """
  @spec histogram(Figure.t(), [number()], keyword()) :: Figure.t()
  def histogram(%Figure{} = fig, observations, opts \\ []) when is_list(observations) do
    bin_opts = Keyword.take(opts, [:bins, :bin_edges, :density])
    {edges, values, density?} = Bland.Histogram.bin(observations, bin_opts)

    remaining = Keyword.drop(opts, [:bins, :bin_edges, :density])

    series =
      struct(Series.Histogram,
        [bin_edges: edges, values: values, density: density?] ++ remaining
      )

    Figure.add_series(fig, series)
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
