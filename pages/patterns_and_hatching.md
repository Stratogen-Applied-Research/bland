# Patterns and Hatching

Hatching is how BLAND replaces color. Every filled region — bar, area —
takes a pattern instead of a fill color. Patterns stay distinguishable
after photocopy, on grayscale printers, and for readers with color
vision deficiency.

## The preset gallery

`Bland.Patterns.preset_cycle/0` returns these in the order the renderer
walks when a series doesn't name a `:hatch` explicitly. The ordering is
tuned for *maximum visual separation* at each step: light hatches
alternate with darker ones, orientation alternates too, and solid-fill
presets sit at the ends of the list.

| Preset              | Description                                         |
| ------------------- | --------------------------------------------------- |
| `:solid_white`      | Paper color (use as a foil behind darker series)    |
| `:diagonal`         | 45° rules, medium spacing                           |
| `:anti_diagonal`    | 135° rules, medium spacing                          |
| `:horizontal`       | Horizontal rules                                    |
| `:vertical`         | Vertical rules                                      |
| `:crosshatch`       | Both diagonals — high visual weight                 |
| `:dots_sparse`      | Small dots on a wide grid                           |
| `:grid`             | Square grid (horizontal + vertical, not crossed)    |
| `:brick`            | Running-bond brick pattern                          |
| `:dots_dense`       | Small dots on a tight grid                          |
| `:zigzag`           | Repeating zigzag line                               |
| `:dashed_h`         | Interrupted horizontal dashes                       |
| `:diagonal_dense`   | Tightly-packed 45° rules                            |
| `:checker`          | 8×8 checker tiling — high weight                    |
| `:solid_black`      | Full fill                                           |

## Usage

Pick by name:

```elixir
Bland.bar(fig, ["A", "B", "C"], [3, 5, 2], hatch: :crosshatch, label: "set 1")
```

Or let the renderer cycle:

```elixir
# No :hatch given → :solid_white, then :diagonal, then :anti_diagonal, …
fig
|> Bland.bar(cats, run_a, label: "A")
|> Bland.bar(cats, run_b, label: "B")
|> Bland.bar(cats, run_c, label: "C")
```

## Choosing patterns

Some practical guidance, gathered from cartography and technical
drafting conventions:

  * **Lighter patterns (dots, sparse lines) for larger regions.** A
    big bar with `:crosshatch` will visually dominate everything else on
    the plot.
  * **Orient hatching differently for adjacent regions.** `:diagonal`
    next to `:anti_diagonal` reads clearly even in a greyscale photo­copy.
  * **Reserve solid fills for emphasis.** Solid black draws the eye
    immediately; use it for the one series you want the reader to see
    first.
  * **Keep stroke weight consistent across fills.** The default pattern
    library draws at 1 px, matching BLAND's default series stroke weight —
    change one and you should change the other.

## Custom patterns

Call `Bland.Patterns.define/4` with a DOM id, tile size, and SVG body:

```elixir
# A pattern of tiny horizontal tick marks
Bland.Patterns.define("my-ticks", {6, 6},
  ~s|<line x1="0" y1="3" x2="6" y2="3" stroke="black" stroke-width="1"/>|
)
```

To use a custom pattern, insert the pattern's `<defs>` into the
generated SVG yourself and reference it via `fill="url(#my-ticks)"`.
The high-level `:hatch` option on `Bland.bar/4` expects a preset atom, so
custom patterns are an "eject into raw SVG" escape hatch.

If you find yourself reaching for the escape hatch often, open an issue
— the preset set is meant to grow.

## Stroke dashes

Lines don't have a fill, but they still need to be distinguishable.
BLAND ships six dash presets, cycled by `Bland.Strokes.preset_cycle/0`:

| Preset       | Dasharray  |
| ------------ | ---------- |
| `:solid`     | (none)     |
| `:dashed`    | `6 3`      |
| `:dotted`    | `1 3`      |
| `:dash_dot`  | `6 3 1 3`  |
| `:long_dash` | `12 4`     |
| `:fine`      | `2 2`      |

`:dash_dot` is the classic centerline / phantom line from mechanical
drafting — useful for reference traces that should visually sit
*behind* the primary curves.

Override with a raw SVG dasharray if you need something off-preset:

```elixir
Bland.line(fig, xs, ys, stroke: "4 2 1 2")
```

## Markers

Scatter and marked lines pull from `Bland.Markers.preset_cycle/0`:

`:circle_open`, `:square_open`, `:triangle_open`, `:diamond_open`,
`:cross`, `:plus`, `:circle_filled`, `:square_filled`,
`:triangle_filled`, `:diamond_filled`, `:asterisk`, `:dot`.

The ordering is alternating-open-then-filled so two adjacent series
look distinct by shape *and* fill.

```elixir
Bland.scatter(fig, xs, ys,
  marker: :triangle_filled,
  marker_size: 5,
  label: "trial 3"
)
```

## A full reference example

```elixir
cats = ["Q1", "Q2", "Q3", "Q4"]

fig =
  Bland.figure(size: :a5_landscape, title: "Pattern reference")
  |> Bland.axes(ylabel: "count")
  |> Bland.bar(cats, [10, 12, 15, 11], label: ":diagonal",      hatch: :diagonal,      group: 1)
  |> Bland.bar(cats, [8,  14, 16, 13], label: ":crosshatch",    hatch: :crosshatch,    group: 2)
  |> Bland.bar(cats, [12, 11, 14, 17], label: ":dots_sparse",   hatch: :dots_sparse,   group: 3)
  |> Bland.bar(cats, [9,  13, 12, 15], label: ":horizontal",    hatch: :horizontal,    group: 4)
  |> Bland.legend(position: :top_left, title: "Fill")

Bland.write!(fig, "patterns.svg")
```
