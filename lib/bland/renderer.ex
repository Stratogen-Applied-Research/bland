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
  alias Bland.Series.{Area, Bar, Histogram, Hline, Line, Scatter, Vline}

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

    {xlim, categories} = resolve_xlim(fig, categorical?)
    ylim = resolve_ylim(fig)

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
      patterns_used: patterns_used
    }
  end

  defp build_scale(:linear, domain, range), do: Scale.linear(domain, range)
  defp build_scale(:log, domain, range), do: Scale.log(domain, range)

  # When a title block is attached, push the plot area up so the block sits
  # in the margin rather than over the curve. We only grow — never shrink —
  # the user's configured margin.
  defp auto_adjust_margins(%Figure{title_block: nil} = fig), do: fig

  defp auto_adjust_margins(%Figure{title_block: tb, margins: {t, r, b, l}, theme: th} = fig) do
    # Leaves room for tick labels, axis label, and the block itself — plus
    # a buffer so the xlabel does not kiss the title block.
    needed = tb.height + th.border_inset + 56
    %{fig | margins: {t, r, max(b, needed), l}}
  end

  defp resolve_xlim(%Figure{xlim: {a, b}}, _), do: {{a, b}, nil}

  defp resolve_xlim(%Figure{xlim: :auto, series: series}, true) do
    categories =
      series
      |> Enum.flat_map(fn
        %Bar{categories: c} -> c
        _ -> []
      end)
      |> Enum.uniq()

    n = length(categories)
    # One slot per category, with half-slot padding on each end.
    {{-0.5, n - 0.5}, categories}
  end

  defp resolve_xlim(%Figure{xlim: :auto, series: series}, false) do
    values = series |> Enum.flat_map(&x_values/1)

    domain =
      case values do
        [] -> {0.0, 1.0}
        _ -> Scale.auto_domain(values, 0.02)
      end

    {domain, nil}
  end

  defp resolve_ylim(%Figure{ylim: {a, b}}), do: {a, b}

  defp resolve_ylim(%Figure{ylim: :auto, series: series}) do
    values = series |> Enum.flat_map(&y_values/1)

    case values do
      [] -> {0.0, 1.0}
      _ -> Scale.auto_domain(values, 0.08)
    end
  end

  defp x_values(%Line{xs: xs}), do: xs
  defp x_values(%Scatter{xs: xs}), do: xs
  defp x_values(%Area{xs: xs}), do: xs
  defp x_values(%Histogram{bin_edges: edges}), do: edges
  defp x_values(%Vline{x: x}), do: [x]
  defp x_values(_), do: []

  defp y_values(%Line{ys: ys}), do: ys
  defp y_values(%Scatter{ys: ys}), do: ys
  defp y_values(%Area{ys: ys, baseline: b}), do: [b | ys]
  defp y_values(%Bar{values: v}), do: [0 | v]
  defp y_values(%Histogram{values: v}), do: [0 | v]
  defp y_values(%Hline{y: y}), do: [y]
  defp y_values(_), do: []

  defp collect_patterns(series) do
    series
    |> Enum.flat_map(fn
      %Bar{hatch: h} -> [h]
      %Area{hatch: h} -> [h]
      %Histogram{hatch: h} -> [h]
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

  defp draw_series(%Area{} = a, index, ctx) do
    hatch = a.hatch || Patterns.cycle(index)
    stroke = a.stroke || :solid
    sw = a.stroke_width || ctx.theme.series_stroke_width
    base_y = Scale.project(ctx.yscale, a.baseline)

    points =
      Enum.zip(a.xs, a.ys)
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
                 xscale: xs, categorical?: cat, categories: cats}) do
    values =
      if cat, do: Enum.with_index(cats) |> Enum.map(fn {_, i} -> i end),
             else: tick_values(f.xscale, xs.domain, f.series)

    Enum.map(values, fn v ->
      x = Scale.project(xs, v)
      len = t.tick_length
      tdir = t.tick_direction

      {y0, y1, ly} =
        case tdir do
          :in -> {py + ph, py + ph - len, py + ph + len + 2}
          :out -> {py + ph, py + ph + len, py + ph + len + 2}
          :both -> {py + ph - len, py + ph + len, py + ph + len + 2}
        end

      label =
        if cat, do: Enum.at(cats, v, "") |> to_string(),
               else: Ticks.format(v)

      [
        Svg.line(x, y0, x, y1,
          stroke: t.foreground,
          "stroke-width": t.tick_stroke_width
        ),
        Svg.text(x, ly + t.tick_label_font_size - 2, Svg.escape(label),
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

  defp y_ticks(%{fig: f, theme: t, plot_rect: {px, _py, _, _ph}, yscale: ys}) do
    values = tick_values(f.yscale, ys.domain, f.series)

    Enum.map(values, fn v ->
      y = Scale.project(ys, v)
      len = t.tick_length

      {x0, x1, lx} =
        case t.tick_direction do
          :in -> {px, px + len, px - 4}
          :out -> {px, px - len, px - len - 4}
          :both -> {px - len, px + len, px - len - 4}
        end

      [
        Svg.line(x0, y, x1, y,
          stroke: t.foreground,
          "stroke-width": t.tick_stroke_width
        ),
        Svg.text(lx, y + t.tick_label_font_size / 2 - 2, Svg.escape(Ticks.format(v)),
          "font-size": t.tick_label_font_size,
          "font-family": t.label_font_family,
          "text-anchor": "end",
          fill: t.foreground
        )
      ]
    end)
  end

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

  defp annotations(%{fig: f, theme: t, xscale: xs, yscale: ys}) do
    Enum.map(f.annotations, fn a -> annotation(a, xs, ys, t) end)
  end

  defp annotation(%{type: :text, x: x, y: y, text: text} = a, xs, ys, t) do
    px = Scale.project(xs, x)
    py = Scale.project(ys, y)

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

  defp annotation(%{type: :arrow, from: {fx, fy}, to: {tx, ty}}, xs, ys, t) do
    x1 = Scale.project(xs, fx)
    y1 = Scale.project(ys, fy)
    x2 = Scale.project(xs, tx)
    y2 = Scale.project(ys, ty)

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

  defp annotation(_, _, _, _), do: []
end
