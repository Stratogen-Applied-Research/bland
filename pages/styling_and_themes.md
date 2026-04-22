# Styling and Themes

A theme is a plain map of typographic and geometric defaults. Every
figure carries one, and every renderer lookup reads through it —
meaning that shifting "the whole plot should feel more like a
blueprint" is a single line change.

## Built-in themes

### `:report_1972` (default)

  * Serif body text (Times-stack)
  * Thin black rules, framed plot area, framed legend
  * Inward-facing tick marks
  * Page border around the full canvas
  * Uppercase titles with letter-spacing — the look of a NASA-contractor
    report typeset on an IBM Selectric

### `:blueprint`

  * Monospace body text (Courier-stack)
  * Thicker strokes (1.4 px axes, 1.4 px series)
  * No plot frame — just L-shaped axes
  * Dense page border
  * Evokes pencil-on-graph-paper working drawings

### `:gazette`

  * Georgia serif body
  * Larger tick and axis labels
  * Mixed-case titles
  * Framed plot area, no page border
  * Newspaper-science-column feel

## Applying a theme

Pass a preset atom to `Bland.figure/1`:

```elixir
Bland.figure(theme: :blueprint)
```

Or a map to override on top of a preset:

```elixir
Bland.figure(theme: Bland.Theme.merge(:report_1972, %{
  title_font_family: "IBM Plex Serif",
  grid_dasharray: "1 6"
}))
```

## The theme map

`Bland.Theme.default/0` is the full reference for what keys exist. The
ones you'll reach for most:

### Typography

| Key                     | Default                             | Purpose                 |
| ----------------------- | ----------------------------------- | ----------------------- |
| `:font_family`          | `"Times, 'Liberation Serif', serif"`| Base text               |
| `:title_font_family`    | same                                | Figure title            |
| `:label_font_family`    | same                                | Axis labels, ticks      |
| `:title_font_size`      | `14`                                | Figure title px         |
| `:subtitle_font_size`   | `11`                                | Subtitle px             |
| `:axis_label_font_size` | `11`                                | xlabel / ylabel px      |
| `:tick_label_font_size` | `9`                                 | Tick labels px          |
| `:legend_font_size`     | `10`                                | Legend text px          |
| `:title_transform`      | `:upcase`                           | `:none | :upcase | :downcase` |
| `:title_letter_spacing` | `"0.05em"`                          | Kerning for figure title|

### Strokes & rules

| Key                     | Default | Purpose                                  |
| ----------------------- | ------- | ---------------------------------------- |
| `:axis_stroke_width`    | `1.0`   | Axis bars (when `frame: false`)          |
| `:frame_stroke_width`   | `1.0`   | Plot-area frame                          |
| `:grid_stroke_width`    | `0.4`   | Grid lines                               |
| `:grid_dasharray`       | `"2 3"` | Grid dashing                             |
| `:series_stroke_width`  | `1.2`   | Default series stroke weight             |
| `:tick_length`          | `5`     | Tick length (px)                         |
| `:tick_direction`       | `:in`   | `:in | :out | :both`                      |
| `:tick_stroke_width`    | `1.0`   | Tick weight                              |

### Layout toggles

| Key                     | Default | Purpose                                  |
| ----------------------- | ------- | ---------------------------------------- |
| `:frame`                | `true`  | Draw a rectangle around the plot area    |
| `:border`               | `true`  | Draw a border around the whole canvas    |
| `:border_inset`         | `12`    | Border offset from canvas edge (px)      |
| `:legend_frame`         | `true`  | Frame the legend box                     |

## Examples

### A more formal report look

```elixir
formal = Bland.Theme.merge(:report_1972, %{
  title_transform: :none,
  title_font_size: 18,
  grid_dasharray: "1 4",
  grid_stroke_width: 0.3
})

Bland.figure(theme: formal, title: "Figure 3-7. Flux density vs wavelength")
```

### Minimal — no frame, no grid, no border

```elixir
minimal = %{
  frame: false,
  border: false,
  grid_stroke_width: 0,
  tick_direction: :out
}

Bland.figure(theme: minimal)
|> Bland.axes(xlabel: "n", ylabel: "f(n)", grid: :none)
|> Bland.line([1, 2, 3, 4], [1, 4, 9, 16])
```

### Blueprint with a darker paper tint

```elixir
paper = Bland.Theme.merge(:blueprint, %{
  background: "#f4f2e8"   # aged-paper cream
})

Bland.figure(theme: paper)
```

(Yes, BLAND lets you set a non-white background — but for true paper
output, leave it `"white"`.)

## Theme introspection

```elixir
iex> t = Bland.Theme.get(:blueprint)
iex> t.font_family
"'Courier New', 'Liberation Mono', monospace"

iex> t.series_stroke_width
1.4
```

If you're building a house style for a project, define it once as a
plain map module attribute and pass it to every `Bland.figure/1` call.
