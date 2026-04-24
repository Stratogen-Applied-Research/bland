defmodule Bland.Grid do
  @moduledoc """
  Composes multiple `%Bland.Figure{}` into one SVG — the multi-panel
  layout tool.

  ![Two-panel subplot](assets/hero_subplots.svg)

  `Bland.grid/2` renders each figure at its native viewBox and places
  the result inside a nested `<svg>` at the appropriate cell, so every
  panel renders independently and keeps its own ticks, labels,
  ornaments.

  This is a **render-time** operation — it does not mutate figures.
  Pass it a list of fully-built figures and it produces an SVG binary.

      fig1 = Bland.figure(title: "Panel A") |> Bland.line(xs, ys1)
      fig2 = Bland.figure(title: "Panel B") |> Bland.line(xs, ys2)

      svg = Bland.grid([fig1, fig2], columns: 2)
      File.write!("paired.svg", svg)

  ## Options

    * `:columns`     — number of columns (default fills one row)
    * `:rows`        — number of rows (default derived from count)
    * `:cell_width`  — pixel width each cell is rendered at. Defaults
      to the first figure's native width.
    * `:cell_height` — same for height
    * `:gap`         — pixel gap between cells (default `16`)
    * `:padding`     — pixel padding around the outer edge (default `20`)
    * `:title`       — optional outer title drawn above the panels
    * `:background`  — outer background color (default `"white"`)
  """

  alias Bland.{Figure, Renderer, Svg}

  @doc """
  Composes `figures` into a single SVG string. See module doc for
  options.
  """
  @spec render([Figure.t()], keyword()) :: String.t()
  def render(figures, opts \\ []) when is_list(figures) and length(figures) > 0 do
    [first | _] = figures

    cell_w = Keyword.get(opts, :cell_width, first.width)
    cell_h = Keyword.get(opts, :cell_height, first.height)
    gap = Keyword.get(opts, :gap, 16)
    padding = Keyword.get(opts, :padding, 20)
    title = Keyword.get(opts, :title)
    background = Keyword.get(opts, :background, "white")

    n = length(figures)
    cols = Keyword.get(opts, :columns, Keyword.get(opts, :rows) && div(n, Keyword.get(opts, :rows)) || n)
    rows = Keyword.get(opts, :rows, ceil(n / cols))

    title_h = if title, do: 36, else: 0

    total_w = padding * 2 + cols * cell_w + (cols - 1) * gap
    total_h = padding * 2 + title_h + rows * cell_h + (rows - 1) * gap

    panels =
      figures
      |> Enum.with_index()
      |> Enum.map(fn {fig, i} ->
        row = div(i, cols)
        col = rem(i, cols)
        x = padding + col * (cell_w + gap)
        y = padding + title_h + row * (cell_h + gap)

        inner = render_inner(fig)

        [
          ~s|<svg x="#{Svg.num(x)}" y="#{Svg.num(y)}" |,
          ~s|width="#{Svg.num(cell_w)}" height="#{Svg.num(cell_h)}" |,
          ~s|viewBox="0 0 #{Svg.num(fig.width)} #{Svg.num(fig.height)}" |,
          ~s|preserveAspectRatio="xMidYMid meet">|,
          inner,
          ~s|</svg>|
        ]
      end)

    title_el =
      if title do
        Svg.text(total_w / 2, padding + 22, Svg.escape(title),
          "font-size": 16,
          "font-family": "Times, 'Liberation Serif', serif",
          "text-anchor": "middle",
          "letter-spacing": "0.05em",
          fill: "black"
        )
      else
        []
      end

    body = [
      Svg.rect(0, 0, total_w, total_h, fill: background),
      title_el,
      panels
    ]

    Svg.document(total_w, total_h, body)
    |> IO.iodata_to_binary()
  end

  # Strips the outer `<?xml?>` prolog and `<svg ...>`/`</svg>` wrapper
  # from a rendered figure so its body can be nested inside a larger SVG.
  defp render_inner(%Figure{} = fig) do
    svg = Renderer.to_svg(fig)

    svg
    |> String.replace(~r|^\s*<\?xml[^>]*\?>\s*|, "")
    |> String.replace(~r|^\s*<svg[^>]*>|, "")
    |> String.replace(~r|</svg>\s*$|, "")
  end
end
