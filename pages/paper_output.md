# Paper Output

BLAND emits SVG. SVG prints beautifully on any modern printer, embeds
cleanly into LaTeX (`\includegraphics{figure.svg}` with the `svg`
package), pastes into Word and Pages, and renders at any DPI without
resampling.

## Canvas sizes

Canvas size is set via `:size` on `Bland.figure/1`. All presets are in
pixels at 96 DPI — which is the browser default and matches the
assumptions of most SVG-to-PDF tools.

| Preset                 | px (w × h)   | mm (w × h, ≈96 DPI) |
| ---------------------- | ------------ | ------------------- |
| `:a5`                  | 559 × 794    | 148 × 210           |
| `:a5_landscape`        | 794 × 559    | 210 × 148           |
| `:a4`                  | 794 × 1123   | 210 × 297           |
| `:a4_landscape`        | 1123 × 794   | 297 × 210           |
| `:letter`              | 816 × 1056   | 216 × 279 (8.5"×11") |
| `:letter_landscape`    | 1056 × 816   | 279 × 216           |
| `:legal`               | 816 × 1344   | 216 × 356 (8.5"×14") |
| `:legal_landscape`     | 1344 × 816   | 356 × 216           |
| `:square`              | 600 × 600    | 159 × 159           |

For custom canvases, pass a tuple:

```elixir
Bland.figure(size: {1600, 1200})
```

## Embedding in LaTeX

With the `svg` package (handles SVG→PDF via Inkscape at compile time):

```latex
\usepackage{svg}
...
\begin{figure}[t]
  \centering
  \includesvg[width=0.8\textwidth]{figures/damped_oscillation.svg}
  \caption{Response of a second-order system.}
\end{figure}
```

If you'd rather ship a PDF in your repo instead of re-running Inkscape
on every build, convert offline:

```sh
rsvg-convert -f pdf -o damped.pdf damped.svg
# or
inkscape damped.svg --export-type=pdf --export-filename=damped.pdf
```

## Embedding in Markdown / GitHub README

GitHub renders SVG directly. Drop the file into the repo and reference
it like a PNG:

```markdown
![Damped oscillation](figures/damped.svg)
```

## Converting to PNG

Browsers, `rsvg-convert`, Inkscape, and headless Chromium all work:

```sh
rsvg-convert -w 2400 -o damped.png damped.svg          # 2x hi-DPI
inkscape damped.svg --export-type=png --export-filename=damped.png --export-dpi=300
```

On macOS, Quick Look can also thumbnail an SVG:

```sh
qlmanage -t -s 1200 -o . damped.svg  # produces damped.svg.png
```

## Printing

Most browsers will print an SVG one-to-one if you set the document size
correctly. BLAND emits `width` and `height` attributes on `<svg>` so the
print box comes out the size you asked for. When embedding in a PDF
from LaTeX or similar, always pass `width=\textwidth` or an explicit
mm size rather than relying on the document's own pixel dimensions.

## DPI and stroke weight

The default theme uses a 1.2 px series stroke, 1.0 px axis stroke, and
0.4 px grid stroke. On a 300 DPI printer those translate to about
0.1 mm (grid), 0.25 mm (axes), and 0.3 mm (series) — which lines up
with typical pen-set drafting weights (0.1 → H3, 0.25 → H2, 0.3 → HB).

If your printer is dropping the grid at 600+ DPI, bump
`:grid_stroke_width` to `0.5`:

```elixir
Bland.figure(theme: Bland.Theme.merge(:report_1972, %{grid_stroke_width: 0.5}))
```

## A full paper-ready recipe

```elixir
fig =
  Bland.figure(
    size: :a4_landscape,
    theme: Bland.Theme.merge(:report_1972, %{
      # Slightly thicker for photocopy survival
      grid_stroke_width: 0.5,
      series_stroke_width: 1.4
    }),
    title: "Figure 3.2 — Thermal response"
  )
  |> Bland.axes(xlabel: "time [min]", ylabel: "T [°C]")
  |> Bland.line(ts, temperatures, label: "measured")
  |> Bland.line(ts, model,        label: "model", stroke: :dashed)
  |> Bland.legend(position: :top_right)
  |> Bland.title_block(
    project:   "Thermal Qualification",
    title:     "Fig. 3.2",
    drawn_by:  "JM",
    checked_by:"RK",
    date:      Date.utc_today() |> Date.to_iso8601(),
    scale:     "1:1",
    sheet:     "12 of 40",
    rev:       "B"
  )

Bland.write!(fig, "figures/fig_3_2.svg")
```

That file will print identically on your laser printer, the departmental
copier, and whatever machine the journal uses to reproduce the paper a
decade from now.
