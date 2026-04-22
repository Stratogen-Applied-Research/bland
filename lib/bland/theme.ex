defmodule Bland.Theme do
  @moduledoc """
  Theme presets and defaults.

  A theme is a plain map of typographic, geometric, and stroke defaults.
  Every figure carries one; overrides can be applied to `Bland.figure/1` via
  `theme:` or by merging maps directly.

  ## Built-in themes

    * `:report_1972` (default) — serif body text, thin black rules,
      inward-facing tick marks, framed plotting area.
    * `:blueprint` — Courier-style monospace labels, borderless axes,
      thicker stroke weights, evokes pencil-on-graph-paper.
    * `:gazette` — compact, high-contrast; title set in small caps, larger
      tick labels. Closer to a newspaper science column.

  You can derive a theme with `merge/2`:

      Bland.Theme.merge(:report_1972, %{font_family: "IBM Plex Serif"})
  """

  @type t :: map()

  @default %{
    name: :report_1972,
    # Typography
    font_family: "Times, 'Liberation Serif', serif",
    title_font_family: "Times, 'Liberation Serif', serif",
    label_font_family: "Times, 'Liberation Serif', serif",
    title_font_size: 14,
    subtitle_font_size: 11,
    axis_label_font_size: 11,
    tick_label_font_size: 9,
    legend_font_size: 10,
    annotation_font_size: 9,
    title_letter_spacing: "0.05em",
    title_transform: :upcase,
    # Colors
    foreground: "black",
    background: "white",
    # Strokes
    axis_stroke_width: 1.0,
    frame_stroke_width: 1.0,
    grid_stroke_width: 0.4,
    grid_dasharray: "2 3",
    series_stroke_width: 1.2,
    tick_length: 4,
    tick_minor_length: 2,
    tick_direction: :in,
    tick_stroke_width: 1.0,
    # Frame around plotting area
    frame: true,
    # Page border around full canvas
    border: true,
    border_stroke_width: 0.8,
    border_inset: 12,
    # Legend
    legend_frame: true,
    legend_stroke_width: 0.8,
    # Marker defaults
    marker_size: 4,
    marker_stroke_width: 1.0
  }

  @blueprint %{
    name: :blueprint,
    font_family: "'Courier New', 'Liberation Mono', monospace",
    title_font_family: "'Courier New', 'Liberation Mono', monospace",
    label_font_family: "'Courier New', 'Liberation Mono', monospace",
    title_font_size: 13,
    axis_label_font_size: 10,
    tick_label_font_size: 9,
    axis_stroke_width: 1.4,
    frame_stroke_width: 1.4,
    series_stroke_width: 1.4,
    grid_dasharray: "1 4",
    grid_stroke_width: 0.5,
    frame: false,
    border: true,
    border_inset: 8,
    tick_direction: :in,
    tick_length: 6
  }

  @gazette %{
    name: :gazette,
    font_family: "Georgia, 'Liberation Serif', serif",
    title_font_family: "Georgia, 'Liberation Serif', serif",
    title_font_size: 16,
    subtitle_font_size: 12,
    tick_label_font_size: 10,
    axis_label_font_size: 12,
    title_letter_spacing: "0.02em",
    title_transform: :none,
    frame: true,
    border: false,
    grid_dasharray: "1 5",
    series_stroke_width: 1.3,
    tick_length: 4,
    tick_direction: :out
  }

  @doc "Returns the canonical default theme (`:report_1972`)."
  @spec default() :: t()
  def default, do: @default

  @doc """
  Fetches a named preset. `name` may be an atom preset or a map; maps are
  returned unchanged so you can pass `theme:` either way.
  """
  @spec get(atom() | t()) :: t()
  def get(theme) when is_map(theme), do: Map.merge(@default, theme)
  def get(:report_1972), do: @default
  def get(:blueprint), do: Map.merge(@default, @blueprint)
  def get(:gazette), do: Map.merge(@default, @gazette)

  def get(unknown),
    do: raise(ArgumentError, "unknown theme #{inspect(unknown)}; expected :report_1972, :blueprint, :gazette, or a map")

  @doc """
  Merges an override map (or keyword list) into a named preset.
  """
  @spec merge(atom() | t(), map() | keyword()) :: t()
  def merge(theme, overrides) when is_list(overrides),
    do: merge(theme, Map.new(overrides))

  def merge(theme, overrides) when is_map(overrides),
    do: Map.merge(get(theme), overrides)

  @doc """
  Applies a text transform declared by the theme (`:upcase`, `:downcase`,
  `:none`). Used by the renderer for titles and headings.
  """
  @spec transform_text(String.t(), atom()) :: String.t()
  def transform_text(text, :upcase), do: String.upcase(text)
  def transform_text(text, :downcase), do: String.downcase(text)
  def transform_text(text, _), do: text
end
