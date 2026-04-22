defmodule Bland.Patterns do
  @moduledoc """
  Monochrome SVG fill patterns — the hatching vocabulary of a 1970s
  technical report.

  Each preset expands to a unique, deterministic `<pattern>` element id. Use
  the preset atom as a fill reference:

      Bland.bar(fig, categories, values, hatch: :diagonal)

  ## Presets

  The shipped presets (in the order you'd typically use them for a
  multi-series plot, maximizing visual separation):

    * `:solid_black`    — fully filled black
    * `:solid_white`    — blank (paper color)
    * `:diagonal`       — 45° lines, medium density
    * `:anti_diagonal`  — 135° lines, medium density
    * `:crosshatch`     — 45° + 135°
    * `:horizontal`     — horizontal rules
    * `:vertical`       — vertical rules
    * `:grid`           — square grid
    * `:dots_sparse`    — small dots, wide spacing
    * `:dots_dense`     — small dots, tight spacing
    * `:brick`          — running-bond brick
    * `:zigzag`         — repeating zigzag line
    * `:checker`        — 8x8 checker tiling
    * `:dashed_h`       — interrupted horizontal dashes
    * `:diagonal_dense` — tightly packed 45° lines

  All presets are rendered with 1px black lines on a transparent ground so
  they compose with any theme stroke color.

  ## Custom patterns

  Build your own with `define/3`:

      Bland.Patterns.define("my-hatch", {10, 10}, ~s|<line x1="0" y1="0" x2="10" y2="10" stroke="black"/>|)
  """

  alias Bland.Svg

  @preset_order [
    :solid_white,
    :diagonal,
    :anti_diagonal,
    :horizontal,
    :vertical,
    :crosshatch,
    :dots_sparse,
    :grid,
    :brick,
    :dots_dense,
    :zigzag,
    :dashed_h,
    :diagonal_dense,
    :checker,
    :solid_black
  ]

  @doc """
  Returns the list of preset names in a recommended cycling order. When a
  multi-series plot does not specify a per-series pattern, the renderer
  walks this list.
  """
  @spec preset_cycle() :: [atom()]
  def preset_cycle, do: @preset_order

  @doc """
  Returns the next `n` patterns from the cycle, skipping any already used.
  """
  @spec cycle(non_neg_integer(), [atom()]) :: atom()
  def cycle(index, exclude \\ []) do
    pool = @preset_order -- exclude
    Enum.at(pool, rem(index, length(pool)))
  end

  @doc """
  Emits the SVG `<pattern>` defs for every preset named in `names`.

  Duplicates are filtered. `:solid_black` and `:solid_white` emit no defs;
  they are handled as direct fills (`"black"`, `"white"`).
  """
  @spec defs([atom()]) :: iodata()
  def defs(names) do
    names
    |> Enum.uniq()
    |> Enum.reject(&(&1 in [:solid_black, :solid_white, nil]))
    |> Enum.map(&preset_def/1)
  end

  @doc """
  Returns an SVG `fill` attribute value for a preset. Solid presets return
  color names; hatch presets return `"url(#bland-pattern-...)"`.
  """
  @spec fill(atom()) :: String.t()
  def fill(:solid_black), do: "black"
  def fill(:solid_white), do: "white"
  def fill(:none), do: "none"
  def fill(name) when is_atom(name), do: "url(##{id(name)})"

  @doc """
  Defines a custom pattern inline. Returns an iodata `<pattern>` element
  suitable for placing in a `<defs>` block. `id` is the DOM id you will
  reference via `fill="url(#<id>)"`.
  """
  @spec define(String.t(), {number(), number()}, iodata(), keyword()) :: iodata()
  def define(id, {w, h}, body, opts \\ []) do
    rotate = Keyword.get(opts, :rotate)

    transform_attr =
      if rotate, do: [~s| patternTransform="rotate(|, Svg.num(rotate), ~s|)"|], else: []

    [
      ~s|<pattern id="|,
      id,
      ~s|" patternUnits="userSpaceOnUse" width="|,
      Svg.num(w),
      ~s|" height="|,
      Svg.num(h),
      ~s|"|,
      transform_attr,
      ">",
      body,
      "</pattern>"
    ]
  end

  @doc "Canonical DOM id for a preset."
  @spec id(atom()) :: String.t()
  def id(name), do: "bland-pattern-" <> Atom.to_string(name)

  # --- preset implementations -----------------------------------------------

  defp preset_def(:diagonal),
    do: define(id(:diagonal), {8, 8}, line(0, 0, 0, 8), rotate: 45)

  defp preset_def(:diagonal_dense),
    do: define(id(:diagonal_dense), {4, 4}, line(0, 0, 0, 4), rotate: 45)

  defp preset_def(:anti_diagonal),
    do: define(id(:anti_diagonal), {8, 8}, line(0, 0, 0, 8), rotate: -45)

  defp preset_def(:horizontal),
    do: define(id(:horizontal), {6, 6}, line(0, 3, 6, 3))

  defp preset_def(:vertical),
    do: define(id(:vertical), {6, 6}, line(3, 0, 3, 6))

  defp preset_def(:crosshatch) do
    define(id(:crosshatch), {10, 10}, [
      line(0, 0, 10, 10),
      line(10, 0, 0, 10)
    ])
  end

  defp preset_def(:grid) do
    define(id(:grid), {8, 8}, [
      line(0, 0, 8, 0),
      line(0, 0, 0, 8)
    ])
  end

  defp preset_def(:dots_sparse),
    do: define(id(:dots_sparse), {10, 10}, dot(5, 5, 1.2))

  defp preset_def(:dots_dense),
    do: define(id(:dots_dense), {5, 5}, dot(2.5, 2.5, 1.0))

  defp preset_def(:brick) do
    define(id(:brick), {16, 8}, [
      # bottom row border
      line(0, 8, 16, 8),
      # vertical joint in the bottom row
      line(0, 4, 0, 8),
      line(16, 4, 16, 8),
      # top row: offset by half a brick
      line(0, 0, 16, 0),
      line(0, 4, 16, 4),
      line(8, 0, 8, 4)
    ])
  end

  defp preset_def(:zigzag) do
    d = "M0 6 L3 2 L6 6 L9 2 L12 6"
    define(id(:zigzag), {12, 8}, ~s|<path d="#{d}" fill="none" stroke="black" stroke-width="1"/>|)
  end

  defp preset_def(:dashed_h) do
    define(id(:dashed_h), {10, 6}, [
      line(0, 3, 5, 3)
    ])
  end

  defp preset_def(:checker) do
    define(id(:checker), {8, 8}, [
      ~s|<rect x="0" y="0" width="4" height="4" fill="black"/>|,
      ~s|<rect x="4" y="4" width="4" height="4" fill="black"/>|
    ])
  end

  defp line(x1, y1, x2, y2) do
    [
      ~s|<line x1="|,
      Svg.num(x1),
      ~s|" y1="|,
      Svg.num(y1),
      ~s|" x2="|,
      Svg.num(x2),
      ~s|" y2="|,
      Svg.num(y2),
      ~s|" stroke="black" stroke-width="1"/>|
    ]
  end

  defp dot(cx, cy, r) do
    [
      ~s|<circle cx="|,
      Svg.num(cx),
      ~s|" cy="|,
      Svg.num(cy),
      ~s|" r="|,
      Svg.num(r),
      ~s|" fill="black"/>|
    ]
  end
end
