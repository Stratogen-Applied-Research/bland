defmodule Bland.Geo do
  @moduledoc """
  Geographic projections for plotting longitude/latitude data.

  Enable a projection on a figure via `Bland.figure(projection: :mercator)`.
  After that, every series treats its `xs` as longitude in degrees and
  `ys` as latitude in degrees, and the renderer projects each point
  through the named projection before applying the usual x/y scales.

  ## Projections

    * `:none` (default) — identity; no projection
    * `:mercator`       — standard web-mercator; y clamped to ±85°
    * `:equirect`       — equirectangular / plate carrée (identity)

  ## Helpers

      iex> {x, y} = Bland.Geo.mercator({0.0, 0.0})
      iex> {abs(Float.round(x, 6)), abs(Float.round(y, 6))}
      {0.0, 0.0}

      iex> {_x, y} = Bland.Geo.mercator({0.0, 45.0})
      iex> Float.round(y, 6)
      0.881374

  ## Coastlines

  ETD ships no built-in coastline data. For simple demos a bounding box
  or hand-drawn outline suffices; for real maps, parse a GeoJSON source
  (e.g. Natural Earth) externally and feed the polygons in as `line/4`
  or `area/4` series with `(lon, lat)` coordinates.
  """

  @mercator_max_lat 85.05112878

  @doc "List of supported projection atoms."
  @spec projections() :: [atom()]
  def projections, do: [:none, :mercator, :equirect]

  @doc """
  Projects `{lon, lat}` (degrees) through `projection`.

  Unknown projections fall back to the identity transform.
  """
  @spec project(atom(), {number(), number()}) :: {float(), float()}
  def project(:none, {lon, lat}), do: {lon * 1.0, lat * 1.0}
  def project(:equirect, {lon, lat}), do: {lon * 1.0, lat * 1.0}
  def project(:mercator, point), do: mercator(point)
  def project(_, {lon, lat}), do: {lon * 1.0, lat * 1.0}

  @doc """
  Web-Mercator projection. Longitudes pass through as radians; latitudes
  are transformed to `ln(tan(π/4 + lat/2))`. Latitudes are clamped to
  `±85.05112878°` (the standard Mercator cutoff) to avoid infinities at
  the poles.
  """
  @spec mercator({number(), number()}) :: {float(), float()}
  def mercator({lon, lat}) do
    lat_clamped = max(-@mercator_max_lat, min(@mercator_max_lat, lat))
    x = lon * :math.pi() / 180.0
    y = :math.log(:math.tan(:math.pi() / 4 + lat_clamped * :math.pi() / 360.0))
    {x, y}
  end

  @doc """
  Equirectangular projection — a no-op pass-through, included for
  symmetry with `mercator/1`.
  """
  @spec equirect({number(), number()}) :: {float(), float()}
  def equirect({lon, lat}), do: {lon * 1.0, lat * 1.0}

  @doc """
  Projects a list of `{lon, lat}` pairs.
  """
  @spec project_all(atom(), [{number(), number()}]) :: [{float(), float()}]
  def project_all(proj, points), do: Enum.map(points, &project(proj, &1))

  @doc """
  Generates a graticule — a list of `{xs, ys}` polyline tuples in lon/lat
  space — suitable for adding as multiple `Bland.line/4` calls.

  ## Options

    * `:lon_step` (default `30`) — spacing of meridians in degrees
    * `:lat_step` (default `30`) — spacing of parallels in degrees
    * `:lat_range` (default `{-80, 80}`) — extent of meridians (keeps
      polar clutter minimal on Mercator)
    * `:lon_range` (default `{-180, 180}`)
    * `:samples` (default `60`) — points per polyline (for curvature
      fidelity under projection)

  Returns a list of `{xs, ys}` tuples. Each is one full meridian or
  parallel traced from endpoint to endpoint.

      graticule = Bland.Geo.graticule(lon_step: 30, lat_step: 20)

      fig =
        Enum.reduce(graticule, base_fig, fn {xs, ys}, acc ->
          Bland.line(acc, xs, ys, stroke: :dotted)
        end)
  """
  @spec graticule(keyword()) :: [{[float()], [float()]}]
  def graticule(opts \\ []) do
    lon_step = Keyword.get(opts, :lon_step, 30)
    lat_step = Keyword.get(opts, :lat_step, 30)
    {lat_lo, lat_hi} = Keyword.get(opts, :lat_range, {-80, 80})
    {lon_lo, lon_hi} = Keyword.get(opts, :lon_range, {-180, 180})
    samples = Keyword.get(opts, :samples, 60)

    meridians =
      Enum.map(range(lon_lo, lon_hi, lon_step), fn lon ->
        lats = linspace(lat_lo, lat_hi, samples)
        {List.duplicate(lon * 1.0, length(lats)), lats}
      end)

    parallels =
      Enum.map(range(lat_lo, lat_hi, lat_step), fn lat ->
        lons = linspace(lon_lo, lon_hi, samples)
        {lons, List.duplicate(lat * 1.0, length(lons))}
      end)

    meridians ++ parallels
  end

  @doc """
  Inscribes the world coastline-less "frame" — a rectangle at the given
  lon/lat range, traced as `{xs, ys}`. Handy as a map boundary when you
  don't have real coastline data.
  """
  @spec world_rect({number(), number()}, {number(), number()}, pos_integer()) ::
          {[float()], [float()]}
  def world_rect({lon_lo, lon_hi}, {lat_lo, lat_hi}, samples \\ 40) do
    top = linspace(lon_lo, lon_hi, samples) |> Enum.map(&{&1, lat_hi * 1.0})
    right = linspace(lat_hi, lat_lo, samples) |> Enum.map(&{lon_hi * 1.0, &1})
    bottom = linspace(lon_hi, lon_lo, samples) |> Enum.map(&{&1, lat_lo * 1.0})
    left = linspace(lat_lo, lat_hi, samples) |> Enum.map(&{lon_lo * 1.0, &1})

    points = top ++ right ++ bottom ++ left
    Enum.unzip(points)
  end

  defp range(lo, hi, step) do
    n = trunc((hi - lo) / step)
    Enum.map(0..n, fn i -> lo + i * step end)
  end

  defp linspace(a, b, n) when n >= 2 do
    step = (b - a) / (n - 1)
    Enum.map(0..(n - 1), fn i -> (a + i * step) * 1.0 end)
  end
end
