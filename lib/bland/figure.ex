defmodule Bland.Figure do
  @moduledoc """
  The plot document.

  A `%Figure{}` holds the canvas dimensions, axis configuration, series
  list, and ornaments (legend, title block, annotations). Builder functions
  return updated figures so the whole pipeline stays immutable:

      Bland.figure(size: :a5_landscape)
      |> Bland.line([1, 2, 3], [1, 4, 9])
      |> Bland.axes(xlabel: "n", ylabel: "n²")
      |> Bland.render()

  ## Paper sizes

  `size:` accepts `{width_px, height_px}` tuples or one of the named paper
  presets (dimensions in pixels at 96 DPI):

    * `:a4`, `:a4_landscape`
    * `:a5`, `:a5_landscape`
    * `:letter`, `:letter_landscape`
    * `:legal`, `:legal_landscape`
    * `:square` — 600×600

  The default is `:letter_landscape`.

  ## Struct fields

    * `:width`, `:height` — canvas dimensions (px)
    * `:margins` — `{top, right, bottom, left}` inside the border
    * `:title`, `:subtitle` — figure text
    * `:xlim`, `:ylim` — data-space limits, or `:auto` (default)
    * `:xscale`, `:yscale` — `:linear` (default) or `:log`
    * `:xlabel`, `:ylabel`
    * `:grid` — `:none | :major | :both`
    * `:series` — list of `%Bland.Series{}` in draw order
    * `:legend` — `%{position: atom, title: string} | nil`
    * `:title_block` — `%Bland.TitleBlock{}` or `nil`
    * `:annotations` — list of `%{type: atom, ...}` overlays
    * `:theme` — map returned by `Bland.Theme.get/1`
  """

  @paper_sizes %{
    a4: {794, 1123},
    a4_landscape: {1123, 794},
    a5: {559, 794},
    a5_landscape: {794, 559},
    letter: {816, 1056},
    letter_landscape: {1056, 816},
    legal: {816, 1344},
    legal_landscape: {1344, 816},
    square: {600, 600}
  }

  @type size :: atom() | {pos_integer(), pos_integer()}

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          margins: {number(), number(), number(), number()},
          title: String.t() | nil,
          subtitle: String.t() | nil,
          xlabel: String.t() | nil,
          ylabel: String.t() | nil,
          xlim: {number(), number()} | :auto,
          ylim: {number(), number()} | :auto,
          xscale: :linear | :log,
          yscale: :linear | :log,
          grid: :none | :major | :both,
          series: [map()],
          legend: map() | nil,
          colorbar: map() | nil,
          title_block: map() | nil,
          annotations: [map()],
          theme: map(),
          projection: atom(),
          clip: :rect | :circle
        }

  defstruct width: 1056,
            height: 816,
            margins: {80, 60, 80, 90},
            title: nil,
            subtitle: nil,
            xlabel: nil,
            ylabel: nil,
            xlim: :auto,
            ylim: :auto,
            xscale: :linear,
            yscale: :linear,
            grid: :major,
            series: [],
            legend: nil,
            colorbar: nil,
            title_block: nil,
            annotations: [],
            theme: nil,
            projection: :none,
            clip: :rect,
            axes: :both

  @doc """
  Builds a new figure. `opts` accepts any of the struct fields, plus
  `:size` (alias for setting `:width` and `:height` from a preset) and
  `:theme` (atom or map, resolved via `Bland.Theme.get/1`).
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    {size, opts} = Keyword.pop(opts, :size, :letter_landscape)
    {width, height} = resolve_size(size)

    {theme, opts} = Keyword.pop(opts, :theme, :report_1972)
    theme = Bland.Theme.get(theme)

    base = %__MODULE__{width: width, height: height, theme: theme}
    struct(base, opts)
  end

  @doc """
  Resolves `:size` to `{width, height}`. Raises on unknown presets.
  """
  @spec resolve_size(size()) :: {pos_integer(), pos_integer()}
  def resolve_size({w, h}) when is_integer(w) and is_integer(h), do: {w, h}

  def resolve_size(name) when is_atom(name) do
    case Map.fetch(@paper_sizes, name) do
      {:ok, dims} ->
        dims

      :error ->
        raise ArgumentError,
              "unknown paper size #{inspect(name)}. " <>
                "Known: #{@paper_sizes |> Map.keys() |> Enum.sort() |> inspect()}"
    end
  end

  @doc "List of built-in paper size presets."
  @spec paper_sizes() :: %{atom() => {pos_integer(), pos_integer()}}
  def paper_sizes, do: @paper_sizes

  @doc """
  Returns the inner plotting rectangle `{x, y, w, h}` in pixel coordinates,
  accounting for the figure's margins.
  """
  @spec plot_rect(t()) :: {number(), number(), number(), number()}
  def plot_rect(%__MODULE__{width: w, height: h, margins: {t, r, b, l}}) do
    {l, t, max(1, w - l - r), max(1, h - t - b)}
  end

  @doc """
  Appends a series to the figure. Accepts a `%Bland.Series.Line{}` or similar
  struct, or any map tagged with `:type`.
  """
  @spec add_series(t(), map()) :: t()
  def add_series(%__MODULE__{series: series} = fig, s) when is_map(s) do
    %{fig | series: series ++ [s]}
  end

  @doc "Updates the figure with a keyword list of overrides."
  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = fig, opts) when is_list(opts) do
    Enum.reduce(opts, fig, fn {k, v}, acc ->
      Map.replace!(acc, k, v)
    end)
  end
end
