defmodule Bland.Strokes do
  @moduledoc """
  Line-style vocabulary for monochrome plots.

  Rather than relying on color to distinguish series, BLAND leans on stroke
  dash patterns and weights — the legibility conventions of ink-on-vellum
  drafting.

  ## Presets

    * `:solid`    — continuous line
    * `:dashed`   — long dashes
    * `:dotted`   — short dots
    * `:dash_dot` — classic centerline / phantom line
    * `:long_dash`— extra-long dashes for emphasis
    * `:fine`    — alternating fine dashes, hairline stroke

  Presets cycle in `preset_cycle/0` order when no explicit `stroke:` is set
  on a series.
  """

  @preset_order [:solid, :dashed, :dotted, :dash_dot, :long_dash, :fine]

  @doc "Stroke presets in recommended cycling order."
  @spec preset_cycle() :: [atom()]
  def preset_cycle, do: @preset_order

  @doc """
  Returns the SVG `stroke-dasharray` value for a preset. `:solid` returns
  `nil` so callers can omit the attribute.
  """
  @spec dasharray(atom()) :: String.t() | nil
  def dasharray(:solid), do: nil
  def dasharray(:dashed), do: "6 3"
  def dasharray(:dotted), do: "1 3"
  def dasharray(:dash_dot), do: "6 3 1 3"
  def dasharray(:long_dash), do: "12 4"
  def dasharray(:fine), do: "2 2"
  def dasharray(custom) when is_binary(custom), do: custom
  def dasharray(list) when is_list(list), do: Enum.join(list, " ")

  @doc "Returns preset at cyclic `index`, skipping any in `exclude`."
  @spec cycle(non_neg_integer(), [atom()]) :: atom()
  def cycle(index, exclude \\ []) do
    pool = @preset_order -- exclude
    Enum.at(pool, rem(index, length(pool)))
  end
end
