defmodule Mix.Tasks.Bland.Basemaps.Compile do
  @shortdoc "Compile GeoJSON basemap sources into vendored Elixir data modules"

  @moduledoc """
  Reads GeoJSON files from `priv/basemaps/source/` and emits Elixir
  data modules to `lib/bland/basemaps/data/`.

  The compiled output is committed to the repository so downstream users
  never need to run this task — it's only re-run when the upstream data
  is updated.

  ## Source files expected

    * `ne_110m_coastline.geojson`        — Natural Earth 1:110m coastlines
    * `ne_50m_coastline.geojson`         — Natural Earth 1:50m coastlines
    * `ne_110m_admin_0_countries.geojson` — 1:110m countries
    * `ne_50m_admin_0_countries.geojson`  — 1:50m countries

  All four are public-domain Natural Earth data; download from
  <https://github.com/nvkelso/natural-earth-vector/tree/master/geojson>.

  ## Usage

      mix bland.basemaps.compile           # all layers
      mix bland.basemaps.compile --precision 2

  Options:

    * `--precision N`  — decimals of coordinate precision to keep
      (default `2` ≈ 1 km resolution, plenty for world-scale plots).
    * `--only LAYER`   — restrict to one layer (e.g. `coastline_50m`).
  """

  use Mix.Task

  @source_dir "priv/basemaps/source"
  @output_dir "lib/bland/basemaps/data"

  @layers [
    %{
      name: "coastline_50m",
      source: "ne_50m_coastline.geojson",
      module: Bland.Basemaps.Data.Coastline50m,
      kind: :coastline
    },
    %{
      name: "coastline_110m",
      source: "ne_110m_coastline.geojson",
      module: Bland.Basemaps.Data.Coastline110m,
      kind: :coastline
    },
    %{
      name: "countries_50m",
      source: "ne_50m_admin_0_countries.geojson",
      module: Bland.Basemaps.Data.Countries50m,
      kind: :countries
    },
    %{
      name: "countries_110m",
      source: "ne_110m_admin_0_countries.geojson",
      module: Bland.Basemaps.Data.Countries110m,
      kind: :countries
    }
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} =
      OptionParser.parse(args,
        switches: [precision: :integer, only: :string]
      )

    precision = Keyword.get(opts, :precision, 2)
    only = Keyword.get(opts, :only)

    File.mkdir_p!(@output_dir)

    @layers
    |> Enum.filter(fn l -> is_nil(only) or l.name == only end)
    |> Enum.each(&compile_layer(&1, precision))
  end

  defp compile_layer(%{name: name, source: src, module: mod, kind: kind}, precision) do
    source_path = Path.join(@source_dir, src)

    unless File.exists?(source_path) do
      Mix.shell().error("Missing source: #{source_path}")
      Mix.shell().info("Download from https://github.com/nvkelso/natural-earth-vector/tree/master/geojson")
      exit(:shutdown)
    end

    Mix.shell().info("Compiling #{name} from #{source_path}…")

    raw = File.read!(source_path)
    # Jason is a dev-only dependency; dispatch indirectly so its absence
    # doesn't warn during normal (non-dev) compilation.
    geojson = apply(Jason, :decode!, [raw])
    features = extract_features(geojson, kind, precision)

    output_path =
      Path.join(@output_dir, "#{name |> String.replace("_", "_")}.ex")
      |> then(fn p ->
        # Use lowercased module suffix for filename consistency
        dir = Path.dirname(p)
        base = name <> ".ex"
        Path.join(dir, base)
      end)

    body = render_module(mod, name, features, kind, src)
    File.write!(output_path, body)

    total_points = Enum.sum(Enum.map(features, fn f -> length(f.points) end))

    Mix.shell().info(
      "  → #{output_path} · #{length(features)} features · #{total_points} points · " <>
        "#{format_bytes(File.stat!(output_path).size)}"
    )
  end

  # -------------------------------------------------------------------------
  # Feature extraction
  # -------------------------------------------------------------------------

  defp extract_features(%{"features" => features}, kind, precision) do
    features
    |> Enum.flat_map(&extract_one(&1, kind, precision))
  end

  # LineString coastlines — one feature per LineString; unnamed
  defp extract_one(%{"geometry" => %{"type" => "LineString", "coordinates" => coords}}, :coastline, p) do
    [
      %{
        name: "coastline",
        points: compress_coords(coords, p),
        closed?: false
      }
    ]
  end

  defp extract_one(
         %{"geometry" => %{"type" => "MultiLineString", "coordinates" => segments}},
         :coastline,
         p
       ) do
    Enum.map(segments, fn seg ->
      %{name: "coastline", points: compress_coords(seg, p), closed?: false}
    end)
  end

  # Country polygons
  defp extract_one(
         %{"geometry" => %{"type" => "Polygon", "coordinates" => rings}, "properties" => props},
         :countries,
         p
       ) do
    name = country_name(props)
    # rings = [outer, hole1, hole2...]. We only keep the outer ring here —
    # BLAND's schematic basemaps don't need cutouts, and stroke-only
    # rendering wouldn't notice interior holes anyway.
    [outer | _] = rings
    [%{name: name, points: compress_coords(outer, p), closed?: true}]
  end

  defp extract_one(
         %{"geometry" => %{"type" => "MultiPolygon", "coordinates" => polygons}, "properties" => props},
         :countries,
         p
       ) do
    name = country_name(props)

    Enum.map(polygons, fn [outer | _holes] ->
      %{name: name, points: compress_coords(outer, p), closed?: true}
    end)
  end

  defp extract_one(_, _, _), do: []

  defp country_name(props) do
    props["ADMIN"] || props["NAME"] || props["SOVEREIGNT"] || "Unknown"
  end

  defp compress_coords(coords, precision) do
    coords
    |> Enum.map(fn [lon, lat] ->
      {Float.round(lon * 1.0, precision), Float.round(lat * 1.0, precision)}
    end)
    |> dedupe_consecutive()
  end

  defp dedupe_consecutive([]), do: []
  defp dedupe_consecutive([x]), do: [x]

  defp dedupe_consecutive([a, b | rest]) when a == b, do: dedupe_consecutive([b | rest])
  defp dedupe_consecutive([a | rest]), do: [a | dedupe_consecutive(rest)]

  # -------------------------------------------------------------------------
  # Elixir code emission
  # -------------------------------------------------------------------------

  defp render_module(module, layer_name, features, kind, source_file) do
    """
    # This file is auto-generated by `mix bland.basemaps.compile`.
    # Do not edit by hand — edit the source GeoJSON at
    # priv/basemaps/source/#{source_file} and re-run the compile task.
    #
    # Source: Natural Earth (naturalearthdata.com) — public domain.
    defmodule #{inspect(module)} do
      @moduledoc false
      # Layer: #{layer_name} (#{kind}) · #{length(features)} features

      @features #{features_literal(features)}

      def features, do: @features
    end
    """
  end

  defp features_literal(features) do
    rendered =
      features
      |> Enum.map(&feature_literal/1)
      |> Enum.join(",\n  ")

    "[\n  " <> rendered <> "\n]"
  end

  defp feature_literal(%{name: name, points: points, closed?: closed?}) do
    pts = points_literal(points)
    "%{name: #{inspect(name)}, closed?: #{closed?}, points: #{pts}}"
  end

  defp points_literal(points) do
    inner =
      points
      |> Enum.map(fn {lon, lat} -> "{#{format_num(lon)}, #{format_num(lat)}}" end)
      |> Enum.join(", ")

    "[" <> inner <> "]"
  end

  defp format_num(v) when is_integer(v), do: "#{v}.0"

  defp format_num(v) when is_float(v) do
    if v == trunc(v), do: "#{trunc(v)}.0", else: Float.to_string(v)
  end

  defp format_bytes(n) when n < 1024, do: "#{n} B"
  defp format_bytes(n) when n < 1_048_576, do: "#{Float.round(n / 1024, 1)} KB"
  defp format_bytes(n), do: "#{Float.round(n / 1_048_576, 1)} MB"
end
