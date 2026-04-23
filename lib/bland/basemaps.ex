defmodule Bland.Basemaps do
  @moduledoc """
  Static base-layer data for geographic figures.

  BLAND ships a hand-curated, low-resolution set of cartographic
  outlines suitable for schematic maps in the tradition of 1960s–80s
  technical reports. The data is embedded in the library — no downloads,
  no external assets, no runtime dependencies.

  > #### Fidelity {: .warning}
  >
  > The shipped outlines are *schematic*, not cartographic. They have
  > enough points to be recognizable at world scale but deliberately
  > trade fidelity for small file size. For precise maps, import a
  > simplified Natural Earth GeoJSON and pass the polylines to
  > `Bland.line/4` or `Bland.polygon/4` directly.

  ## Available layers

  ### Earth (longitude ± 180°, latitude ± 90°)

    * `:earth_coastlines` — continental outlines and major islands
    * `:earth_borders`    — simplified outlines of major countries
    * `:earth_tropics`    — Tropic of Cancer, equator, Tropic of
      Capricorn, Arctic / Antarctic circles as labelled horizontal
      reference lines

  ### Moon (selenographic longitude ± 180°, latitude ± 90°)

    * `:moon_maria` — simplified outlines of the major lunar maria
      (Imbrium, Serenitatis, Tranquillitatis, Crisium, Fecunditatis,
      Nectaris, Nubium, Humorum, Frigoris, Procellarum, Cognitum,
      Vaporum)

  ## Use via `Bland.basemap/3`

      fig
      |> Bland.basemap(:earth_coastlines)
      |> Bland.basemap(:earth_borders, stroke: :dashed)

      fig
      |> Bland.basemap(:moon_maria, hatch: :dots_sparse)

  ## Programmatic access

  `features/1` returns the raw feature list for a layer, which you can
  feed directly into your own series calls for full control:

      for %{name: n, points: pts} <- Bland.Basemaps.features(:earth_coastlines) do
        IO.puts("\#{n}: \#{length(pts)} points")
      end

  Each feature is `%{name: String.t(), points: [{lon, lat}], closed?: bool}`.
  """

  alias Bland.Basemaps.{Earth, Moon}

  @type feature :: %{name: String.t(), points: [{float(), float()}], closed?: boolean()}
  @type layer ::
          :earth_coastlines
          | :earth_borders
          | :earth_tropics
          | :moon_maria

  @type resolution :: :low | :high | :schematic

  @doc """
  Returns the list of features for a basemap layer.

  For Earth layers (`:earth_coastlines`, `:earth_borders`), the
  optional `resolution` selects between the vendored Natural Earth
  datasets:

    * `:low`       — 1:110m (default). Fast, small, recognizable at
      world scale.
    * `:high`      — 1:50m. Detailed enough for regional views;
      ~2.8 MB of compiled data.
    * `:schematic` — BLAND's hand-curated schematic outlines.

  `:earth_tropics` and `:moon_maria` ignore the resolution argument —
  their data isn't resolution-scaled.

  Each feature is a map with `:name`, `:points`, and `:closed?` fields.

  Raises `ArgumentError` for unknown layers.
  """
  @spec features(layer(), resolution()) :: [feature()]
  def features(layer, resolution \\ :low)

  def features(:earth_coastlines, res), do: Earth.coastlines(res)
  def features(:earth_borders, res), do: Earth.borders(res)
  def features(:earth_tropics, _res), do: Earth.tropics()
  def features(:moon_maria, _res), do: Moon.maria()

  def features(unknown, _res),
    do:
      raise(ArgumentError,
        "unknown basemap layer #{inspect(unknown)}. Known: " <>
          "#{inspect(layers())}"
      )

  @doc "All available layer names."
  @spec layers() :: [layer()]
  def layers,
    do: [:earth_coastlines, :earth_borders, :earth_tropics, :moon_maria]

  @doc """
  Returns `{xs, ys}` for a feature, suitable for piping into
  `Bland.line/4` or `Bland.polygon/4`.
  """
  @spec unzip(feature()) :: {[float()], [float()]}
  def unzip(%{points: pts}), do: Enum.unzip(pts)
end
