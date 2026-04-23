defmodule Bland.Renderer do
  @moduledoc """
  Figure-to-SVG renderer.

  `to_svg/1` takes an `%Bland.Figure{}` and returns the finished SVG as a
  binary. All geometry is computed here; series only carry data, and the
  renderer owns projection, tick placement, pattern defs, and the layout
  of ornaments.

  Broad layout, outside-in:

      ┌── page border ────────────────────────────────────────┐
      │  TITLE                                                │
      │  subtitle                                             │
      │         ┌── plot frame ─────────────────┐             │
      │         │                               │   [legend]  │
      │   y     │                               │             │
      │   lbl   │          plotting area        │             │
      │         │                               │             │
      │         └───────────────────────────────┘             │
      │                   x label                             │
      │                                        [title block]  │
      └───────────────────────────────────────────────────────┘
  """

  alias Bland.{Figure, Patterns, Scale, Svg, Theme, Ticks}
  alias Bland.Series.{Area, Bar, Heatmap, Histogram, Hline, Line, Polygon, Scatter, Vline}

  @doc """
  Renders a figure to an SVG binary.
  """
  @spec to_svg(Figure.t()) :: String.t()
  def to_svg(%Figure{} = fig) do
    ctx = build_context(fig)

    body = [
      background(ctx),
      page_border(ctx),
      defs(ctx),
      title_and_subtitle(ctx),
      grid(ctx),
      series_layer(ctx),
      axes_layer(ctx),
      axis_labels(ctx),
      legend(ctx),
      colorbar(ctx),
      title_block(ctx),
      annotations(ctx)
    ]

    Svg.document(fig.width, fig.height, body)
    |> IO.iodata_to_binary()
  end

  # --- context --------------------------------------------------------------

  defp build_context(%Figure{} = fig) do
    fig = auto_adjust_margins(fig)
    {px, py, pw, ph} = Figure.plot_rect(fig)
    categorical? = Enum.any?(fig.series, &match?(%Bar{}, &1))

    projection = fig.projection || :none

    {xlim, categories} = resolve_xlim(fig, categorical?, projection)
    ylim = resolve_ylim(fig, projection)

    # For geographic projections, also compute the raw lon/lat domain so
    # axis ticks can be generated in degrees rather than in projected
    # radians / log-tangent units.
    {geo_xlim, geo_ylim} =
      if projection != :none and not categorical? do
        {resolve_geo_xlim(fig), resolve_geo_ylim(fig)}
      else
        {nil, nil}
      end

    xscale = build_scale(fig.xscale, xlim, {px, px + pw})
    yscale = build_scale(fig.yscale, ylim, {py + ph, py})

    patterns_used = collect_patterns(fig.series)

    %{
      fig: fig,
      theme: fig.theme,
      plot_rect: {px, py, pw, ph},
      xscale: xscale,
      yscale: yscale,
      categories: categories,
      categorical?: categorical?,
      patterns_used: patterns_used,
      projection: projection,
      geo_xlim: geo_xlim,
      geo_ylim: geo_ylim
    }
  end

  # Raw lon/lat extent for geographic figures. When the user sets
  # `:xlim`/`:ylim` explicitly, that's already in degrees and we just
  # return it. For `:auto`, collect all series coordinates unprojected.
  defp resolve_geo_xlim(%Figure{xlim: {a, b}}), do: {a, b}

  defp resolve_geo_xlim(%Figure{xlim: :auto, series: series}) do
    lons = series |> Enum.flat_map(&xy_points/1) |> Enum.map(&elem(&1, 0))

    case lons do
      [] -> {-180.0, 180.0}
      _ -> Scale.auto_domain(lons, 0.0)
    end
  end

  defp resolve_geo_ylim(%Figure{ylim: {a, b}}), do: {a, b}

  defp resolve_geo_ylim(%Figure{ylim: :auto, series: series}) do
    lats = series |> Enum.flat_map(&xy_points/1) |> Enum.map(&elem(&1, 1))

    y_only = series |> Enum.flat_map(&y_only_values/1)
    all = lats ++ y_only

    case all do
      [] -> {-80.0, 80.0}
      _ -> Scale.auto_domain(all, 0.0)
    end
  end

  defp build_scale(:linear, domain, range), do: Scale.linear(domain, range)
  defp build_scale(:log, domain, range), do: Scale.log(domain, range)

  # When a title block is attached, push the plot area up so the block sits
  # in the margin rather than over the curve. We only grow — never shrink —
  # the user's configured margin.
  defp auto_adjust_margins(%Figure{} = fig) do
    fig
    |> adjust_for_title_block()
    |> adjust_for_colorbar()
  end

  defp adjust_for_title_block(%Figure{title_block: nil} = fig), do: fig

  defp adjust_for_title_block(%Figure{title_block: tb, margins: {t, r, b, l}, theme: th} = fig) do
    # Leaves room for tick labels, axis label, and the block itself — plus
    # a buffer so the xlabel does not kiss the title block.
    needed = tb.height + th.border_inset + 56
    %{fig | margins: {t, r, max(b, needed), l}}
  end

  defp adjust_for_colorbar(%Figure{colorbar: nil} = fig), do: fig

  defp adjust_for_colorbar(%Figure{colorbar: cb, margins: {t, r, b, l}} = fig) do
    case Map.get(cb, :position, :right) do
      :right -> %{fig | margins: {t, max(r, 110), b, l}}
      :left -> %{fig | margins: {t, r, b, max(l, 130)}}
      :bottom -> %{fig | margins: {t, r, max(b, 80), l}}
      _ -> fig
    end
  end

  defp resolve_xlim(%Figure{xlim: {a, b}}, _, proj) do
    {xa, _} = project_xy({a, 0}, proj)
    {xb, _} = project_xy({b, 0}, proj)
    {{xa, xb}, nil}
  end

  defp resolve_xlim(%Figure{xlim: :auto, series: series}, true, _proj) do
    categories =
      series
      |> Enum.flat_map(fn
        %Bar{categories: c} -> c
        _ -> []
      end)
      |> Enum.uniq()

    n = length(categories)
    {{-0.5, n - 0.5}, categories}
  end

  defp resolve_xlim(%Figure{xlim: :auto, series: series}, false, proj) do
    values = series |> Enum.flat_map(&xy_points/1) |> project_points(proj) |> Enum.map(&elem(&1, 0))

    domain =
      case values do
        [] -> {0.0, 1.0}
        _ -> Scale.auto_domain(values, 0.02)
      end

    {domain, nil}
  end

  defp resolve_ylim(%Figure{ylim: {a, b}}, proj) do
    project_xy_y_range({a, b}, proj)
  end

  defp resolve_ylim(%Figure{ylim: :auto, series: series}, proj) do
    values = series |> Enum.flat_map(&xy_points/1) |> project_points(proj) |> Enum.map(&elem(&1, 1))

    # Series that contribute only y data (hline, histogram, bar) aren't
    # in xy_points; fold them in here with lon/lat→y identity.
    y_only = series |> Enum.flat_map(&y_only_values/1)
    all = values ++ y_only

    case all do
      [] -> {0.0, 1.0}
      _ -> Scale.auto_domain(all, 0.08)
    end
  end

  # `xy_points` returns `[{x,y}, ...]` for series that carry 2D coordinates.
  defp xy_points(%Line{xs: xs, ys: ys}), do: Enum.zip(xs, ys)
  defp xy_points(%Scatter{xs: xs, ys: ys}), do: Enum.zip(xs, ys)
  defp xy_points(%Area{xs: xs, ys: ys, baseline: b}),
    do: Enum.zip(xs, ys) ++ [{List.first(xs) || 0, b}, {List.last(xs) || 0, b}]
  defp xy_points(%Histogram{bin_edges: edges}),
    do: Enum.map(edges, fn e -> {e, 0} end)
  defp xy_points(%Heatmap{x_edges: nil}), do: []
  defp xy_points(%Heatmap{x_edges: xe, y_edges: ye}) do
    # Four corners suffice for extent.
    [{List.first(xe), List.first(ye)}, {List.last(xe), List.last(ye)}]
  end
  defp xy_points(%Polygon{xs: xs, ys: ys}), do: Enum.zip(xs, ys)
  defp xy_points(%Vline{x: x}), do: [{x, 0}]
  defp xy_points(_), do: []

  defp y_only_values(%Histogram{values: v}), do: [0 | v]
  defp y_only_values(%Bar{values: v}), do: [0 | v]
  defp y_only_values(%Hline{y: y}), do: [y]
  defp y_only_values(_), do: []

  defp project_points(points, :none), do: points
  defp project_points(points, proj), do: Enum.map(points, &project_xy(&1, proj))

  defp project_xy({x, y}, :none), do: {x, y}
  defp project_xy({x, y}, proj), do: Bland.Geo.project(proj, {x, y})

  defp project_xy_y_range({a, b}, :none), do: {a, b}

  defp project_xy_y_range({a, b}, proj) do
    {_, ya} = Bland.Geo.project(proj, {0, a})
    {_, yb} = Bland.Geo.project(proj, {0, b})
    {ya, yb}
  end

  defp collect_patterns(series) do
    series
    |> Enum.flat_map(fn
      %Bar{hatch: h} -> [h]
      %Area{hatch: h} -> [h]
      %Histogram{hatch: h} -> [h]
      %Polygon{hatch: h} -> [h]
      %Heatmap{ramp: r} when is_list(r) -> r
      %Heatmap{ramp: nil} -> Bland.Heatmap.default_ramp()
      _ -> []
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  # --- background / border / defs -------------------------------------------

  defp background(%{fig: f, theme: t}) do
    Svg.rect(0, 0, f.width, f.height, fill: t.background)
  end

  defp page_border(%{theme: %{border: false}}), do: []

  defp page_border(%{fig: f, theme: t}) do
    inset = t.border_inset

    Svg.rect(inset, inset, f.width - 2 * inset, f.height - 2 * inset,
      fill: "none",
      stroke: t.foreground,
      stroke_width: t.border_stroke_width
    )
  end

  defp defs(%{patterns_used: []}), do: []

  defp defs(%{patterns_used: used}) do
    Svg.defs(Patterns.defs(used))
  end

  # --- title / subtitle -----------------------------------------------------

  defp title_and_subtitle(%{fig: f, theme: t, plot_rect: {px, _, pw, _}}) do
    base_y = div(elem(f.margins, 0), 2) + 2
    center_x = px + pw / 2

    [
      if f.title do
        text =
          Theme.transform_text(f.title, t.title_transform)
          |> Svg.escape()

        Svg.text(center_x, base_y, text,
          "font-size": t.title_font_size,
          "font-family": t.title_font_family,
          "text-anchor": "middle",
          "letter-spacing": t.title_letter_spacing,
          fill: t.foreground
        )
      else
        []
      end,
      if f.subtitle do
        Svg.text(center_x, base_y + t.title_font_size + 4, Svg.escape(f.subtitle),
          "font-size": t.subtitle_font_size,
          "font-family": t.title_font_family,
          "text-anchor": "middle",
          fill: t.foreground,
          "font-style": "italic"
        )
      else
        []
      end
    ]
  end

  # --- grid -----------------------------------------------------------------

  defp grid(%{fig: %{grid: :none}}), do: []

  defp grid(%{fig: f, theme: t, plot_rect: {px, py, pw, ph}, xscale: xs, yscale: ys}) do
    xticks = tick_values(f.xscale, xs.domain, f.series)
    yticks = tick_values(f.yscale, ys.domain, f.series)

    x_lines =
      Enum.map(xticks, fn v ->
        x = Scale.project(xs, v)

        Svg.line(x, py, x, py + ph,
          stroke: t.foreground,
          stroke_width: t.grid_stroke_width,
          "stroke-dasharray": t.grid_dasharray
        )
      end)

    y_lines =
      Enum.map(yticks, fn v ->
        y = Scale.project(ys, v)

        Svg.line(px, y, px + pw, y,
          stroke: t.foreground,
          stroke_width: t.grid_stroke_width,
          "stroke-dasharray": t.grid_dasharray
        )
      end)

    Svg.g([opacity: 0.7], [x_lines, y_lines])
  end

  defp tick_values(:linear, domain, _series), do: Ticks.nice(domain, 6)
  defp tick_values(:log, domain, _series), do: Ticks.log_nice(domain, 10)

  # --- series ---------------------------------------------------------------

  defp series_layer(ctx) do
    clip_id = "bland-clip-plot"
    {px, py, pw, ph} = ctx.plot_rect

    clip_def =
      Svg.defs([
        ~s|<clipPath id="#{clip_id}"><rect x="#{Svg.num(px)}" y="#{Svg.num(py)}" width="#{Svg.num(pw)}" height="#{Svg.num(ph)}"/></clipPath>|
      ])

    drawn =
      ctx.fig.series
      |> Enum.with_index()
      |> Enum.map(fn {s, i} -> draw_series(s, i, ctx) end)

    [clip_def, Svg.g(["clip-path": "url(##{clip_id})"], drawn)]
  end

  defp draw_series(%Line{} = l, index, ctx) do
    stroke = l.stroke || Bland.Strokes.cycle(index)
    sw = l.stroke_width || ctx.theme.series_stroke_width

    points =
      Enum.zip(l.xs, l.ys)
      |> Enum.map(&project_xy(&1, ctx.projection))
      |> Enum.map(fn {x, y} -> {Scale.project(ctx.xscale, x), Scale.project(ctx.yscale, y)} end)

    line =
      Svg.polyline(points,
        stroke: ctx.theme.foreground,
        "stroke-width": sw,
        "stroke-linecap": "round",
        "stroke-linejoin": "round",
        "stroke-dasharray": Bland.Strokes.dasharray(stroke)
      )

    marker_layer =
      if l.markers do
        marker = l.marker || Bland.Markers.cycle(index)

        Enum.map(points, fn {x, y} ->
          Bland.Markers.draw(marker, x, y,
            size: l.marker_size || ctx.theme.marker_size,
            stroke_width: ctx.theme.marker_stroke_width
          )
        end)
      else
        []
      end

    [line, marker_layer]
  end

  defp draw_series(%Scatter{} = s, index, ctx) do
    marker = s.marker || Bland.Markers.cycle(index)
    sz = s.marker_size || ctx.theme.marker_size
    sw = s.stroke_width || ctx.theme.marker_stroke_width

    Enum.zip(s.xs, s.ys)
    |> Enum.map(&project_xy(&1, ctx.projection))
    |> Enum.map(fn {x, y} ->
      Bland.Markers.draw(marker, Scale.project(ctx.xscale, x),
                               Scale.project(ctx.yscale, y),
                               size: sz,
                               stroke_width: sw)
    end)
  end

  defp draw_series(%Bar{} = b, index, ctx) do
    hatch = b.hatch || Patterns.cycle(index)
    sw = b.stroke_width || ctx.theme.series_stroke_width

    bar_groups =
      ctx.fig.series
      |> Enum.filter(&match?(%Bar{}, &1))

    group_keys =
      bar_groups
      |> Enum.map(& &1.group)
      |> Enum.uniq()

    group_count = length(group_keys)
    group_index = Enum.find_index(group_keys, &(&1 == b.group)) || 0

    slot_width = category_slot_width(ctx)
    bar_width = slot_width / max(group_count, 1) * 0.8

    offset = (group_index - (group_count - 1) / 2) * (bar_width * 1.05)
    baseline_y = Scale.project(ctx.yscale, 0)

    Enum.zip(b.categories, b.values)
    |> Enum.map(fn {cat, v} ->
      case Enum.find_index(ctx.categories, &(&1 == cat)) do
        nil ->
          []

        idx ->
          cx = Scale.project(ctx.xscale, idx) + offset
          y = Scale.project(ctx.yscale, v)
          top = min(y, baseline_y)
          h = abs(y - baseline_y)

          Svg.rect(cx - bar_width / 2, top, bar_width, h,
            fill: Patterns.fill(hatch),
            stroke: ctx.theme.foreground,
            "stroke-width": sw
          )
      end
    end)
  end

  defp draw_series(%Heatmap{} = h, _index, ctx) do
    ramp = h.ramp || Bland.Heatmap.default_ramp()
    n_levels = length(ramp)

    range =
      case h.range do
        :auto -> Bland.Heatmap.extent(h.data)
        {_lo, _hi} = r -> r
      end

    rows = h.data
    n_rows = length(rows)

    x_edges = h.x_edges
    y_edges = h.y_edges

    rows
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, ri} ->
      # Map data row index to the pair of y_edges this row occupies.
      # With :bottom_left origin, data[0] sits at y_edges[0..1]; with
      # :top_left, data[0] sits at the top, i.e. y_edges[n-1..n].
      y_index =
        case h.origin do
          :top_left -> n_rows - 1 - ri
          _ -> ri
        end

      y_lo = Enum.at(y_edges, y_index)
      y_hi = Enum.at(y_edges, y_index + 1)

      row
      |> Enum.with_index()
      |> Enum.map(fn {val, ci} ->
        x_lo = Enum.at(x_edges, ci)
        x_hi = Enum.at(x_edges, ci + 1)

        level = Bland.Heatmap.quantize(val, range, n_levels)
        pattern = Enum.at(ramp, level)

        px_l = Scale.project(ctx.xscale, x_lo)
        px_r = Scale.project(ctx.xscale, x_hi)
        py_lo = Scale.project(ctx.yscale, y_lo)
        py_hi = Scale.project(ctx.yscale, y_hi)

        x = min(px_l, px_r)
        y = min(py_lo, py_hi)
        w = abs(px_r - px_l)
        height = abs(py_hi - py_lo)

        Svg.rect(x, y, w, height,
          fill: Patterns.fill(pattern),
          stroke: "none"
        )
      end)
    end)
  end

  defp draw_series(%Histogram{bin_edges: edges, values: vals} = h, index, ctx) do
    hatch = h.hatch || Patterns.cycle(index)
    sw = h.stroke_width || ctx.theme.series_stroke_width
    baseline_y = Scale.project(ctx.yscale, 0)

    edges
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.zip(vals)
    |> Enum.map(fn {[lo, hi], v} ->
      x_left = Scale.project(ctx.xscale, lo)
      x_right = Scale.project(ctx.xscale, hi)
      y_top_raw = Scale.project(ctx.yscale, v)
      top = min(y_top_raw, baseline_y)
      height = abs(y_top_raw - baseline_y)
      width = abs(x_right - x_left)

      Svg.rect(min(x_left, x_right), top, width, height,
        fill: Patterns.fill(hatch),
        stroke: ctx.theme.foreground,
        "stroke-width": sw,
        "stroke-linejoin": "miter"
      )
    end)
  end

  defp draw_series(%Polygon{xs: xs, ys: ys} = p, _index, ctx) do
    stroke = p.stroke || :solid
    sw = p.stroke_width || ctx.theme.series_stroke_width

    points =
      Enum.zip(xs, ys)
      |> Enum.map(&project_xy(&1, ctx.projection))
      |> Enum.map(fn {x, y} -> {Scale.project(ctx.xscale, x), Scale.project(ctx.yscale, y)} end)

    case points do
      [] ->
        []

      _ ->
        fill =
          case p.hatch do
            nil -> "none"
            :none -> "none"
            h -> Patterns.fill(h)
          end

        Svg.polygon(points,
          fill: fill,
          stroke: ctx.theme.foreground,
          "stroke-width": sw,
          "stroke-dasharray": Bland.Strokes.dasharray(stroke),
          "stroke-linejoin": "round"
        )
    end
  end

  defp draw_series(%Area{} = a, index, ctx) do
    hatch = a.hatch || Patterns.cycle(index)
    stroke = a.stroke || :solid
    sw = a.stroke_width || ctx.theme.series_stroke_width
    base_y = Scale.project(ctx.yscale, a.baseline)

    points =
      Enum.zip(a.xs, a.ys)
      |> Enum.map(&project_xy(&1, ctx.projection))
      |> Enum.map(fn {x, y} -> {Scale.project(ctx.xscale, x), Scale.project(ctx.yscale, y)} end)

    case points do
      [] ->
        []

      _ ->
        {first_x, _} = hd(points)
        {last_x, _} = List.last(points)
        closed = [{first_x, base_y}] ++ points ++ [{last_x, base_y}]

        fill =
          Svg.polygon(closed,
            fill: Patterns.fill(hatch),
            stroke: "none"
          )

        outline =
          Svg.polyline(points,
            stroke: ctx.theme.foreground,
            "stroke-width": sw,
            "stroke-dasharray": Bland.Strokes.dasharray(stroke),
            "stroke-linejoin": "round"
          )

        [fill, outline]
    end
  end

  defp draw_series(%Hline{} = h, _index, ctx) do
    {px, _, pw, _} = ctx.plot_rect
    y = Scale.project(ctx.yscale, h.y)

    Svg.line(px, y, px + pw, y,
      stroke: ctx.theme.foreground,
      "stroke-width": h.stroke_width,
      "stroke-dasharray": Bland.Strokes.dasharray(h.stroke)
    )
  end

  defp draw_series(%Vline{} = v, _index, ctx) do
    {_, py, _, ph} = ctx.plot_rect
    x = Scale.project(ctx.xscale, v.x)

    Svg.line(x, py, x, py + ph,
      stroke: ctx.theme.foreground,
      "stroke-width": v.stroke_width,
      "stroke-dasharray": Bland.Strokes.dasharray(v.stroke)
    )
  end

  defp category_slot_width(%{xscale: xs, categories: [_, _ | _]}),
    do: abs(Scale.project(xs, 1) - Scale.project(xs, 0))

  defp category_slot_width(%{plot_rect: {_, _, pw, _}}), do: pw * 0.6

  # --- axes -----------------------------------------------------------------

  defp axes_layer(%{theme: t, plot_rect: {px, py, pw, ph}} = ctx) do
    frame =
      if t.frame do
        Svg.rect(px, py, pw, ph,
          fill: "none",
          stroke: t.foreground,
          "stroke-width": t.frame_stroke_width
        )
      else
        [
          Svg.line(px, py + ph, px + pw, py + ph,
            stroke: t.foreground,
            "stroke-width": t.axis_stroke_width
          ),
          Svg.line(px, py, px, py + ph,
            stroke: t.foreground,
            "stroke-width": t.axis_stroke_width
          )
        ]
      end

    [frame, x_ticks(ctx), y_ticks(ctx)]
  end

  defp x_ticks(%{fig: f, theme: t, plot_rect: {px, py, pw, ph},
                 xscale: xs, categorical?: cat, categories: cats,
                 projection: proj, geo_xlim: geo_xlim}) do
    # Three cases: categorical (labels = category names), geographic
    # (ticks in degrees, labels formatted "30°E"), or the plain linear/
    # log numeric path.
    {values, project_val, label_for} =
      cond do
        cat ->
          vals = cats |> Enum.with_index() |> Enum.map(fn {_, i} -> i end)
          {vals, fn v -> v end, fn v -> Enum.at(cats, v, "") |> to_string() end}

        proj != :none and not is_nil(geo_xlim) ->
          vals = nice_geo_ticks(geo_xlim, 7)
          {vals, fn lon -> elem(project_xy({lon, 0}, proj), 0) end, &format_lon_deg/1}

        true ->
          {tick_values(f.xscale, xs.domain, f.series), fn v -> v end, &Ticks.format/1}
      end

    tdir = t.tick_direction
    len = t.tick_length

    {y0, y1, ly} =
      case tdir do
        :in -> {py + ph, py + ph - len, py + ph + len + 2}
        :out -> {py + ph, py + ph + len, py + ph + len + 2}
        :both -> {py + ph - len, py + ph + len, py + ph + len + 2}
      end

    Enum.map(values, fn v ->
      x = Scale.project(xs, project_val.(v))

      [
        Svg.line(x, y0, x, y1,
          stroke: t.foreground,
          "stroke-width": t.tick_stroke_width
        ),
        Svg.text(x, ly + t.tick_label_font_size - 2, Svg.escape(label_for.(v)),
          "font-size": t.tick_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "middle",
          fill: t.foreground
        )
      ]
    end)
    |> then(&[&1, clipped_x_extent_guard(px, pw)])
  end

  defp clipped_x_extent_guard(_px, _pw), do: []

  defp y_ticks(%{fig: f, theme: t, plot_rect: {px, _py, _, _ph}, yscale: ys,
                 projection: proj, geo_ylim: geo_ylim}) do
    {values, project_val, label_for} =
      if proj != :none and not is_nil(geo_ylim) do
        vals = nice_geo_ticks(geo_ylim, 6)
        {vals, fn lat -> elem(project_xy({0, lat}, proj), 1) end, &format_lat_deg/1}
      else
        {tick_values(f.yscale, ys.domain, f.series), fn v -> v end, &Ticks.format/1}
      end

    len = t.tick_length

    {x0, x1, lx} =
      case t.tick_direction do
        :in -> {px, px + len, px - 4}
        :out -> {px, px - len, px - len - 4}
        :both -> {px - len, px + len, px - len - 4}
      end

    Enum.map(values, fn v ->
      y = Scale.project(ys, project_val.(v))

      [
        Svg.line(x0, y, x1, y,
          stroke: t.foreground,
          "stroke-width": t.tick_stroke_width
        ),
        Svg.text(lx, y + t.tick_label_font_size / 2 - 2, Svg.escape(label_for.(v)),
          "font-size": t.tick_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "end",
          fill: t.foreground
        )
      ]
    end)
  end

  # --- geographic tick helpers ---------------------------------------------

  # Picks nice-rounded degree ticks (every 1°, 5°, 10°, 15°, 30°, 45°, 90°)
  # depending on domain span. Target is approximate tick count.
  @geo_steps [1, 2, 5, 10, 15, 20, 30, 45, 60, 90]

  defp nice_geo_ticks({a, b}, target) when a != b do
    {lo, hi} = if a < b, do: {a, b}, else: {b, a}
    span = hi - lo
    raw_step = span / max(target, 1)
    step = Enum.find(@geo_steps, fn s -> s >= raw_step end) || 90

    start = :math.ceil(lo / step) * step
    stop = :math.floor(hi / step) * step
    n = round((stop - start) / step)

    if n < 0, do: [], else: Enum.map(0..n, fn i -> start + i * step end)
  end

  defp format_lon_deg(v) do
    # Normalize float ticks that happen to land on integers (from nice_geo_ticks)
    v = if is_float(v) and v == trunc(v), do: trunc(v), else: v

    cond do
      v == 0 -> "0°"
      v > 0 and v <= 180 -> "#{fmt_deg(v)}°E"
      v < 0 and v >= -180 -> "#{fmt_deg(-v)}°W"
      # Past the antimeridian, wrap — e.g. 190°E == 170°W
      v > 180 -> "#{fmt_deg(360 - v)}°W"
      v < -180 -> "#{fmt_deg(v + 360)}°E"
    end
  end

  defp format_lat_deg(v) do
    v = if is_float(v) and v == trunc(v), do: trunc(v), else: v

    cond do
      v == 0 -> "0°"
      v > 0 -> "#{fmt_deg(v)}°N"
      true -> "#{fmt_deg(-v)}°S"
    end
  end

  defp fmt_deg(v) when is_integer(v), do: Integer.to_string(v)
  defp fmt_deg(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 1)

  defp axis_labels(%{fig: f, theme: t, plot_rect: {px, py, pw, ph}}) do
    # When the title block is attached we auto-expanded the bottom margin,
    # so keep the axis label close to the ticks to leave room for the block
    # below. Without the block, breathe a little more.
    xlabel_gap = if f.title_block, do: 16, else: 22

    [
      if f.xlabel do
        Svg.text(
          px + pw / 2,
          py + ph + t.tick_length + t.tick_label_font_size + xlabel_gap,
          Svg.escape(f.xlabel),
          "font-size": t.axis_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "middle",
          fill: t.foreground,
          "font-style": "italic"
        )
      else
        []
      end,
      if f.ylabel do
        lx = px - 44
        ly = py + ph / 2

        Svg.text(lx, ly, Svg.escape(f.ylabel),
          "font-size": t.axis_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "middle",
          fill: t.foreground,
          "font-style": "italic",
          transform: "rotate(-90 #{Svg.num(lx)} #{Svg.num(ly)})"
        )
      else
        []
      end
    ]
  end

  # --- legend ---------------------------------------------------------------

  defp legend(%{fig: %{legend: nil}}), do: []

  defp legend(%{fig: f, theme: t, plot_rect: {px, py, pw, ph}} = ctx) do
    entries = legend_entries(f.series)
    {pos, title} = {Map.get(f.legend, :position, :top_right), Map.get(f.legend, :title)}

    row_h = t.legend_font_size + 6
    swatch_w = 28
    label_pad = 8
    vpad = 6
    extra_title = if title, do: row_h + 2, else: 0

    box_h = length(entries) * row_h + 2 * vpad + extra_title
    # Legend box width grows with the longest label
    max_label =
      entries
      |> Enum.map(fn {label, _, _} -> String.length(label) end)
      |> Enum.max(fn -> 6 end)

    box_w = swatch_w + label_pad + max(80, max_label * (t.legend_font_size * 0.55)) + 12

    {bx, by} =
      case pos do
        :top_right -> {px + pw - box_w - 8, py + 8}
        :top_left -> {px + 8, py + 8}
        :bottom_right -> {px + pw - box_w - 8, py + ph - box_h - 8}
        :bottom_left -> {px + 8, py + ph - box_h - 8}
        {x, y} -> {x, y}
      end

    frame =
      if t.legend_frame do
        Svg.rect(bx, by, box_w, box_h,
          fill: t.background,
          stroke: t.foreground,
          "stroke-width": t.legend_stroke_width
        )
      else
        []
      end

    title_el =
      if title do
        Svg.text(bx + 8, by + vpad + row_h - 3, Svg.escape(title),
          "font-size": t.legend_font_size,
          "font-family": t.font_family,
          "font-weight": "bold",
          fill: t.foreground
        )
      else
        []
      end

    row_start_y = by + vpad + extra_title

    rows =
      entries
      |> Enum.with_index()
      |> Enum.map(fn {{label, kind, style}, i} ->
        y = row_start_y + i * row_h
        swatch_y = y + row_h / 2 - 4
        swatch_x = bx + 8

        swatch = legend_swatch(kind, style, swatch_x, swatch_y, swatch_w, ctx)

        [
          swatch,
          Svg.text(swatch_x + swatch_w + label_pad, y + row_h - 3, Svg.escape(label),
            "font-size": t.legend_font_size,
            "font-family": t.font_family,
            fill: t.foreground
          )
        ]
      end)

    [frame, title_el, rows]
  end

  defp legend_entries(series) do
    series
    |> Enum.with_index()
    |> Enum.flat_map(fn {s, i} -> legend_entry(s, i) end)
  end

  defp legend_entry(%Line{label: nil}, _), do: []

  defp legend_entry(%Line{label: label} = l, i) do
    stroke = l.stroke || Bland.Strokes.cycle(i)
    marker = if l.markers, do: l.marker || Bland.Markers.cycle(i), else: nil
    [{label, :line, %{stroke: stroke, marker: marker}}]
  end

  defp legend_entry(%Scatter{label: nil}, _), do: []

  defp legend_entry(%Scatter{label: label} = s, i) do
    marker = s.marker || Bland.Markers.cycle(i)
    [{label, :scatter, %{marker: marker}}]
  end

  defp legend_entry(%Bar{label: nil}, _), do: []

  defp legend_entry(%Bar{label: label} = b, i) do
    hatch = b.hatch || Patterns.cycle(i)
    [{label, :bar, %{hatch: hatch}}]
  end

  defp legend_entry(%Histogram{label: nil}, _), do: []

  defp legend_entry(%Histogram{label: label} = h, i) do
    hatch = h.hatch || Patterns.cycle(i)
    [{label, :bar, %{hatch: hatch}}]
  end

  defp legend_entry(%Area{label: nil}, _), do: []

  defp legend_entry(%Area{label: label} = a, i) do
    hatch = a.hatch || Patterns.cycle(i)
    [{label, :area, %{hatch: hatch, stroke: a.stroke || :solid}}]
  end

  defp legend_entry(%Hline{label: label, stroke: stroke}, _) when not is_nil(label),
    do: [{label, :line, %{stroke: stroke, marker: nil}}]

  defp legend_entry(%Vline{label: label, stroke: stroke}, _) when not is_nil(label),
    do: [{label, :line, %{stroke: stroke, marker: nil}}]

  defp legend_entry(_, _), do: []

  defp legend_swatch(:line, %{stroke: stroke, marker: marker}, x, y, w, ctx) do
    cy = y + 4

    [
      Svg.line(x, cy, x + w, cy,
        stroke: ctx.theme.foreground,
        "stroke-width": ctx.theme.series_stroke_width,
        "stroke-dasharray": Bland.Strokes.dasharray(stroke)
      ),
      if(marker,
        do:
          Bland.Markers.draw(marker, x + w / 2, cy,
            size: ctx.theme.marker_size - 1,
            stroke_width: ctx.theme.marker_stroke_width
          ),
        else: []
      )
    ]
  end

  defp legend_swatch(:scatter, %{marker: marker}, x, y, w, ctx) do
    cy = y + 4

    [
      Bland.Markers.draw(marker, x + w / 2, cy,
        size: ctx.theme.marker_size,
        stroke_width: ctx.theme.marker_stroke_width
      )
    ]
  end

  defp legend_swatch(:bar, %{hatch: hatch}, x, y, w, ctx) do
    Svg.rect(x, y - 3, w, 12,
      fill: Patterns.fill(hatch),
      stroke: ctx.theme.foreground,
      "stroke-width": 1
    )
  end

  defp legend_swatch(:area, %{hatch: hatch, stroke: stroke}, x, y, w, ctx) do
    [
      Svg.rect(x, y - 3, w, 12,
        fill: Patterns.fill(hatch),
        stroke: "none"
      ),
      Svg.line(x, y - 3, x + w, y - 3,
        stroke: ctx.theme.foreground,
        "stroke-width": 1,
        "stroke-dasharray": Bland.Strokes.dasharray(stroke)
      )
    ]
  end

  # --- title block ----------------------------------------------------------

  # --- colorbar -------------------------------------------------------------

  defp colorbar(%{fig: %{colorbar: nil}}), do: []

  defp colorbar(%{fig: f, theme: t, plot_rect: {px, py, pw, ph}}) do
    opts = f.colorbar
    heatmap = find_colorbar_heatmap(f.series)

    ramp = Map.get(opts, :ramp) || (heatmap && heatmap.ramp) || Bland.Heatmap.default_ramp()

    range =
      Map.get(opts, :range) ||
        case heatmap do
          %{range: {_, _} = r} -> r
          %{data: data} -> Bland.Heatmap.extent(data)
          _ -> {0.0, 1.0}
        end

    label = Map.get(opts, :label) || (heatmap && heatmap.label)
    position = Map.get(opts, :position, :right)
    tick_count = Map.get(opts, :levels, 5)

    bar_w = 16
    gap = 14
    tick_px = 36

    {bar_x, bar_y, bar_h} =
      case position do
        :right -> {px + pw + gap, py, ph}
        :left -> {px - gap - bar_w - tick_px, py, ph}
        :bottom -> {px, py + ph + 24, ph}
        {x, y} -> {x, y, ph}
      end

    segments = render_ramp_segments(ramp, bar_x, bar_y, bar_w, bar_h, t)
    frame =
      Svg.rect(bar_x, bar_y, bar_w, bar_h,
        fill: "none",
        stroke: t.foreground,
        "stroke-width": t.axis_stroke_width
      )

    ticks = render_ramp_ticks(range, bar_x, bar_y, bar_w, bar_h, tick_count, position, t)

    label_el =
      if label do
        {lx, ly} =
          case position do
            :right -> {bar_x + bar_w + tick_px + 8, bar_y + bar_h / 2}
            :left -> {bar_x - 8, bar_y + bar_h / 2}
            _ -> {bar_x + bar_w / 2, bar_y + bar_h + 18}
          end

        rotation =
          case position do
            :bottom -> ""
            _ -> " rotate(-90 #{Svg.num(lx)} #{Svg.num(ly)})"
          end

        Svg.text(lx, ly, Svg.escape(label),
          "font-size": t.axis_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "middle",
          fill: t.foreground,
          "font-style": "italic",
          transform: "translate(0 0)" <> rotation
        )
      else
        []
      end

    [segments, frame, ticks, label_el]
  end

  defp find_colorbar_heatmap(series) do
    series
    |> Enum.reverse()
    |> Enum.find(&match?(%Heatmap{}, &1))
  end

  defp render_ramp_segments(ramp, bx, by, bw, bh, _t) do
    n = length(ramp)
    step = bh / n

    ramp
    |> Enum.with_index()
    |> Enum.map(fn {pattern, i} ->
      # i=0 (lightest) at bottom, i=n-1 (darkest) at top
      y = by + bh - (i + 1) * step

      Svg.rect(bx, y, bw, step,
        fill: Patterns.fill(pattern),
        stroke: "none"
      )
    end)
  end

  defp render_ramp_ticks({lo, hi}, bx, by, bw, bh, count, position, t) do
    count = max(count, 2)

    Enum.map(0..(count - 1), fn i ->
      frac = i / (count - 1)
      val = lo + frac * (hi - lo)
      # frac = 0 → bottom (lo), frac = 1 → top (hi)
      y = by + bh - frac * bh

      {tick_x_from, tick_x_to, label_x, anchor} =
        case position do
          :left -> {bx, bx - 4, bx - 6, "end"}
          _ -> {bx + bw, bx + bw + 4, bx + bw + 6, "start"}
        end

      [
        Svg.line(tick_x_from, y, tick_x_to, y,
          stroke: t.foreground,
          "stroke-width": t.tick_stroke_width
        ),
        Svg.text(label_x, y + t.tick_label_font_size / 2 - 2,
          Svg.escape(Ticks.format(val)),
          "font-size": t.tick_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": anchor,
          fill: t.foreground
        )
      ]
    end)
  end

  # --- title block ----------------------------------------------------------

  defp title_block(%{fig: %{title_block: nil}}), do: []

  defp title_block(%{fig: f, theme: t}) do
    tb = f.title_block
    w = tb.width
    h = tb.height

    {bx, by} =
      case tb.position do
        :bottom_right ->
          {f.width - w - (t.border_inset + 8), f.height - h - (t.border_inset + 8)}

        :bottom_left ->
          {t.border_inset + 8, f.height - h - (t.border_inset + 8)}
      end

    # Layout (proportional, so things scale if users set a custom width/height).
    #
    #  ┌────────────────────────────┬──────────────┐
    #  │ PROJECT                    │ DRAWN        │
    #  │  <project>                 │  <drawn_by>  │   ~35% of height
    #  ├────────────────────────────┼──────────────┤
    #  │ TITLE                      │ CHECKED      │
    #  │  <title>         (bold)    │  <checked>   │   ~35%
    #  ├──────────────┬─────────────┼──────────────┤
    #  │ DATE         │ SCALE       │ SHEET   REV  │
    #  │  <date>      │  <scale>    │  <sheet> <r> │   ~30%
    #  └──────────────┴─────────────┴──────────────┘
    left_w = w * 0.66
    col_mid = bx + left_w
    row1_y = by + h * 0.35
    row2_y = by + h * 0.70

    sub_col_w = left_w / 2
    sub_mid = bx + sub_col_w
    rev_mid = col_mid + (w - left_w) * 0.55

    frame =
      Svg.rect(bx, by, w, h,
        fill: t.background,
        stroke: t.foreground,
        "stroke-width": 1.2
      )

    rules = [
      Svg.line(bx, row1_y, bx + w, row1_y, stroke: t.foreground, "stroke-width": 0.8),
      Svg.line(bx, row2_y, bx + w, row2_y, stroke: t.foreground, "stroke-width": 0.8),
      Svg.line(col_mid, by, col_mid, by + h, stroke: t.foreground, "stroke-width": 0.8),
      Svg.line(sub_mid, row2_y, sub_mid, by + h, stroke: t.foreground, "stroke-width": 0.8),
      Svg.line(rev_mid, row2_y, rev_mid, by + h, stroke: t.foreground, "stroke-width": 0.8)
    ]

    font = ["font-family": t.label_font_family, fill: t.foreground]
    small = [{:"font-size", 8} | font]
    normal = [{:"font-size", 10} | font]
    bold = [{:"font-weight", "bold"} | normal]

    # Helpers that render a label/value pair inside a cell. The offsets
    # are deliberately tight so the narrower bottom row (30% of total
    # height) still has breathing room under the value text.
    label_value = fn cx, cy, label, value, value_attrs ->
      [
        Svg.text(cx + 6, cy + 10, Svg.escape(label), small),
        Svg.text(cx + 6, cy + 22, Svg.escape(to_string(value || "—")), value_attrs)
      ]
    end

    cells = [
      label_value.(bx, by, "PROJECT", tb.project, normal),
      label_value.(col_mid, by, "DRAWN", tb.drawn_by, normal),
      label_value.(bx, row1_y, "TITLE", tb.title, bold),
      label_value.(col_mid, row1_y, "CHECKED", tb.checked_by, normal),
      label_value.(bx, row2_y, "DATE", tb.date, normal),
      label_value.(sub_mid, row2_y, "SCALE", tb.scale, normal),
      label_value.(col_mid, row2_y, "SHEET", tb.sheet, normal),
      label_value.(rev_mid, row2_y, "REV", tb.rev, bold)
    ]

    [frame, rules, cells]
  end

  # --- annotations ----------------------------------------------------------

  defp annotations(%{fig: %{annotations: []}}), do: []

  defp annotations(%{fig: f, theme: t, xscale: xs, yscale: ys, projection: proj}) do
    Enum.map(f.annotations, fn a -> annotation(a, xs, ys, t, proj) end)
  end

  defp annotation(%{type: :text, x: x, y: y, text: text} = a, xs, ys, t, proj) do
    {px_data, py_data} = project_xy({x, y}, proj)
    px = Scale.project(xs, px_data)
    py = Scale.project(ys, py_data)

    # `paint-order: stroke` draws the stroke first and the fill on top, so
    # a thick background-colored stroke becomes a halo that keeps the
    # label legible when it crosses a curve or reference line.
    halo = Map.get(a, :halo, true)

    Svg.text(px, py, Svg.escape(text),
      "font-size": Map.get(a, :font_size, t.annotation_font_size),
      "font-family": t.label_font_family,
      fill: t.foreground,
      stroke: if(halo, do: t.background, else: nil),
      "stroke-width": if(halo, do: 3, else: nil),
      "stroke-linejoin": if(halo, do: "round", else: nil),
      "paint-order": if(halo, do: "stroke", else: nil),
      "text-anchor": Map.get(a, :anchor, "start")
    )
  end

  defp annotation(%{type: :arrow, from: {fx, fy}, to: {tx, ty}}, xs, ys, t, proj) do
    {fpx, fpy} = project_xy({fx, fy}, proj)
    {tpx, tpy} = project_xy({tx, ty}, proj)
    x1 = Scale.project(xs, fpx)
    y1 = Scale.project(ys, fpy)
    x2 = Scale.project(xs, tpx)
    y2 = Scale.project(ys, tpy)

    # Simple arrow: line + small triangle at the tip
    angle = :math.atan2(y2 - y1, x2 - x1)
    head = 6
    ax1 = x2 - head * :math.cos(angle - :math.pi() / 8)
    ay1 = y2 - head * :math.sin(angle - :math.pi() / 8)
    ax2 = x2 - head * :math.cos(angle + :math.pi() / 8)
    ay2 = y2 - head * :math.sin(angle + :math.pi() / 8)

    [
      Svg.line(x1, y1, x2, y2, stroke: t.foreground, "stroke-width": 1),
      Svg.polygon([{x2, y2}, {ax1, ay1}, {ax2, ay2}], fill: t.foreground)
    ]
  end

  defp annotation(_, _, _, _, _), do: []
end
