defmodule BlandTest do
  use ExUnit.Case, async: true
  doctest Bland.Scale
  doctest Bland.Ticks
  doctest Bland.Histogram
  doctest Bland.Heatmap
  doctest Bland.Geo

  describe "figure/1" do
    test "builds a default letter-landscape figure" do
      fig = Bland.figure()
      assert fig.width == 1056
      assert fig.height == 816
      assert fig.theme.name == :report_1972
    end

    test "accepts named paper sizes" do
      fig = Bland.figure(size: :a4)
      assert {fig.width, fig.height} == {794, 1123}
    end

    test "accepts tuple size" do
      fig = Bland.figure(size: {640, 480})
      assert {fig.width, fig.height} == {640, 480}
    end

    test "accepts a theme atom" do
      fig = Bland.figure(theme: :blueprint)
      assert fig.theme.name == :blueprint
      assert fig.theme.font_family =~ "Courier"
    end

    test "unknown paper size raises" do
      assert_raise ArgumentError, fn -> Bland.figure(size: :tabloid_custom) end
    end
  end

  describe "series builders" do
    test "line/4 appends a line series with data" do
      fig = Bland.figure() |> Bland.line([1, 2, 3], [1, 4, 9], label: "squared")

      assert [%Bland.Series.Line{xs: [1, 2, 3], ys: [1, 4, 9], label: "squared"}] = fig.series
    end

    test "scatter/4, bar/4, area/4, hline/3, vline/3 all produce tagged structs" do
      fig =
        Bland.figure()
        |> Bland.scatter([1, 2], [3, 4])
        |> Bland.bar(["A", "B"], [1, 2])
        |> Bland.area([1, 2, 3], [0, 1, 0])
        |> Bland.hline(0.0, label: "zero")
        |> Bland.vline(1.5)

      types = Enum.map(fig.series, & &1.type)
      assert types == [:scatter, :bar, :area, :hline, :vline]
    end

    test "histogram/3 bins eagerly and stores edges + counts" do
      samples = [1, 2, 2, 3, 3, 3, 4, 4, 5]
      fig = Bland.figure() |> Bland.histogram(samples, bins: 4, label: "samples")

      [%Bland.Series.Histogram{bin_edges: edges, values: values, label: "samples",
                             normalize: :count}] = fig.series

      assert length(edges) == 5
      assert length(values) == 4
      assert Enum.sum(values) == length(samples)
    end

    test "histogram/3 with normalize: :pmf keeps bar rendering" do
      fig =
        Bland.figure()
        |> Bland.histogram([1, 2, 3, 4, 5], bins: 5, normalize: :pmf, label: "pmf")

      [%Bland.Series.Histogram{normalize: :pmf, values: vals}] = fig.series
      assert_in_delta Enum.sum(vals), 1.0, 1.0e-9
    end

    test "histogram/3 with normalize: :cmf adds a Line series (staircase)" do
      samples = Enum.map(1..100, &(&1 * 1.0))
      fig =
        Bland.figure()
        |> Bland.histogram(samples, bins: 10, normalize: :cmf, label: "F(x)")

      # Step line instead of a Histogram bar series
      [%Bland.Series.Line{xs: xs, ys: ys, label: "F(x)"}] = fig.series

      # Starts at 0, ends at 1, monotonic
      assert List.first(ys) == 0.0
      assert_in_delta List.last(ys), 1.0, 1.0e-9
      assert Enum.chunk_every(ys, 2, 1, :discard) |> Enum.all?(fn [a, b] -> b >= a end)

      # Staircase: 1 + 2n points for n bins
      assert length(xs) == 1 + 2 * 10
    end
  end

  describe "annotate/2" do
    test "adds text annotations" do
      fig = Bland.figure() |> Bland.annotate(text: "x", at: {1.0, 2.0})
      assert [%{type: :text, x: 1.0, y: 2.0, text: "x"}] = fig.annotations
    end

    test "adds arrow annotations" do
      fig = Bland.figure() |> Bland.annotate(arrow: {{0, 0}, {1, 1}})
      assert [%{type: :arrow, from: {0, 0}, to: {1, 1}}] = fig.annotations
    end

    test "bad options raise" do
      assert_raise ArgumentError, fn ->
        Bland.figure() |> Bland.annotate(foo: :bar)
      end
    end
  end

  describe "to_svg/1" do
    setup do
      xs = Enum.map(0..20, &(&1 / 2.0))
      ys = Enum.map(xs, &:math.sin/1)
      {:ok, xs: xs, ys: ys}
    end

    test "produces a valid-looking SVG with line data", %{xs: xs, ys: ys} do
      svg = Bland.figure(title: "sin(x)") |> Bland.line(xs, ys, label: "sin") |> Bland.to_svg()

      assert String.starts_with?(svg, "<?xml version=\"1.0\"")
      assert svg =~ "<svg"
      assert svg =~ "viewBox"
      assert String.ends_with?(svg, "</svg>")
      assert svg =~ "<polyline"
    end

    test "emits pattern defs for bar hatches" do
      svg =
        Bland.figure()
        |> Bland.bar(["A", "B", "C"], [1, 3, 2], hatch: :diagonal, label: "bars")
        |> Bland.legend()
        |> Bland.to_svg()

      assert svg =~ ~s|<pattern id="bland-pattern-diagonal"|
      assert svg =~ "url(#bland-pattern-diagonal)"
    end

    test "emits title block when attached" do
      svg =
        Bland.figure()
        |> Bland.line([0, 1], [0, 1])
        |> Bland.title_block(project: "ORION", title: "Fig. 1", drawn_by: "JM", rev: "A")
        |> Bland.to_svg()

      assert svg =~ "PROJECT"
      assert svg =~ "ORION"
      assert svg =~ "DRAWN"
      assert svg =~ "REV"
    end

    test "escapes user text" do
      # Default theme upper-cases the title for that engineering-report look,
      # but the XML escaping still needs to happen after the transform.
      svg =
        Bland.figure(title: "5 < x & y > 3")
        |> Bland.line([0, 1], [0, 1])
        |> Bland.to_svg()

      assert svg =~ "5 &lt; X &amp; Y &gt; 3"
    end

    test "log scale produces different projection" do
      xs = [1.0, 10.0, 100.0, 1000.0]
      fig = Bland.figure() |> Bland.axes(xscale: :log, xlim: {1, 1000}) |> Bland.line(xs, xs)
      svg = Bland.to_svg(fig)
      # Should compile cleanly and emit polyline
      assert svg =~ "<polyline"
    end
  end

  describe "Bland.Scale" do
    test "linear scale projects endpoints exactly" do
      s = Bland.Scale.linear({0.0, 10.0}, {0.0, 100.0})
      assert Bland.Scale.project(s, 0.0) == 0.0
      assert Bland.Scale.project(s, 10.0) == 100.0
      assert Bland.Scale.project(s, 5.0) == 50.0
    end

    test "inversion round-trips linear values" do
      s = Bland.Scale.linear({-3.0, 7.0}, {20.0, 220.0})
      for v <- [-3.0, 0.0, 2.5, 7.0] do
        assert_in_delta Bland.Scale.invert(s, Bland.Scale.project(s, v)), v, 1.0e-9
      end
    end

    test "log scale compresses exponentials to equal intervals" do
      s = Bland.Scale.log({1.0, 1000.0}, {0.0, 300.0})
      a = Bland.Scale.project(s, 10.0)
      b = Bland.Scale.project(s, 100.0)
      c = Bland.Scale.project(s, 1000.0)
      assert_in_delta b - a, c - b, 1.0e-9
    end

    test "auto_domain pads symmetrically" do
      {lo, hi} = Bland.Scale.auto_domain([0.0, 10.0], 0.1)
      assert lo == -1.0
      assert hi == 11.0
    end
  end

  describe "Bland.Ticks" do
    test "nice returns values within domain" do
      ticks = Bland.Ticks.nice({0.0, 9.7}, 6)
      assert Enum.all?(ticks, &(&1 >= 0.0 and &1 <= 9.7))
      assert length(ticks) >= 4
    end

    test "log_nice returns powers of base" do
      ticks = Bland.Ticks.log_nice({1.0, 1000.0}, 10)
      assert ticks == [1.0, 10.0, 100.0, 1000.0]
    end

    test "format trims trailing zeros" do
      assert Bland.Ticks.format(1.5) == "1.5"
      assert Bland.Ticks.format(1.0) == "1"
      assert Bland.Ticks.format(1.500) == "1.5"
    end
  end

  describe "Bland.Histogram" do
    test "integer bin count produces exactly that many bins" do
      {edges, counts, _} = Bland.Histogram.bin(Enum.to_list(1..100), bins: 10)
      assert length(edges) == 11
      assert length(counts) == 10
      assert Enum.sum(counts) == 100
    end

    test "explicit bin_edges overrides :bins" do
      {edges, counts, _} =
        Bland.Histogram.bin([0.5, 1.5, 2.5, 3.5], bin_edges: [0.0, 1.0, 2.0, 3.0, 4.0])

      assert edges == [0.0, 1.0, 2.0, 3.0, 4.0]
      assert counts == [1, 1, 1, 1]
    end

    test ":sturges scales with sample count" do
      {e_small, _, _} = Bland.Histogram.bin(Enum.to_list(1..16), bins: :sturges)
      {e_large, _, _} = Bland.Histogram.bin(Enum.to_list(1..1024), bins: :sturges)

      assert length(e_small) - 1 <= length(e_large) - 1
    end

    test ":sqrt gives ceil(sqrt n) bins" do
      {edges, _, _} = Bland.Histogram.bin(Enum.to_list(1..100), bins: :sqrt)
      assert length(edges) == 11
    end

    test ":density normalizes so Σ v·w = 1" do
      samples = [1, 2, 2, 3, 3, 3, 4, 4, 5]
      {edges, values, :density} = Bland.Histogram.bin(samples, bins: 4, density: true)

      widths =
        edges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [lo, hi] -> hi - lo end)

      total_area = Enum.zip(values, widths) |> Enum.map(fn {v, w} -> v * w end) |> Enum.sum()
      assert_in_delta total_area, 1.0, 1.0e-9
    end

    test ":pmf normalizes so Σ v = 1" do
      samples = [1, 2, 2, 3, 3, 3, 4, 4, 5]
      {_edges, values, :pmf} = Bland.Histogram.bin(samples, bins: 4, normalize: :pmf)

      assert_in_delta Enum.sum(values), 1.0, 1.0e-9
    end

    test ":cmf values are monotonic, start positive and end at 1" do
      samples = Enum.map(1..100, &(&1 * 1.0))
      {_edges, values, :cmf} = Bland.Histogram.bin(samples, bins: 10, normalize: :cmf)

      assert length(values) == 10
      assert values |> List.first() > 0.0
      assert_in_delta List.last(values), 1.0, 1.0e-9

      assert Enum.chunk_every(values, 2, 1, :discard)
             |> Enum.all?(fn [a, b] -> b >= a end)
    end

    test ":cmf on empty input yields zeros without exploding" do
      {_edges, values, :cmf} = Bland.Histogram.bin([], bins: 5, normalize: :cmf)
      assert Enum.sum(values) == 0
    end

    test "resolve_normalize honors :density backwards-compat shorthand" do
      assert Bland.Histogram.resolve_normalize(density: true) == :density
      assert Bland.Histogram.resolve_normalize(density: false) == :count
      assert Bland.Histogram.resolve_normalize(normalize: :pmf) == :pmf
    end

    test "unknown :normalize raises" do
      assert_raise ArgumentError, fn ->
        Bland.Histogram.bin([1, 2, 3], normalize: :bogus)
      end
    end

    test "staircase/2 produces the right-continuous CDF shape" do
      {xs, ys} = Bland.Histogram.staircase([0.0, 1.0, 2.0, 3.0], [0.25, 0.75, 1.0])

      # 1 start + 3 bins × 2 points each = 7
      assert length(xs) == 7
      assert List.first(ys) == 0.0
      assert List.last(ys) == 1.0
      # Monotonic non-decreasing
      assert Enum.chunk_every(ys, 2, 1, :discard) |> Enum.all?(fn [a, b] -> b >= a end)
    end

    test "observations outside the edge range are dropped" do
      {_, counts, _} =
        Bland.Histogram.bin([-1.0, 0.5, 1.5, 99.0], bin_edges: [0.0, 1.0, 2.0])

      assert counts == [1, 1]
    end

    test "empty input is handled without raising" do
      {edges, counts, _} = Bland.Histogram.bin([], bins: 5)
      assert is_list(edges)
      assert Enum.sum(counts) == 0
    end

    test "identical observations don't collapse to zero-width domain" do
      {[lo, hi | _], _, _} = Bland.Histogram.bin([3.0, 3.0, 3.0, 3.0], bins: 2)
      assert lo < hi
    end

    test "renders flush bars with no category gap" do
      samples = Enum.map(1..200, fn i -> rem(i, 10) * 1.0 end)
      svg =
        Bland.figure()
        |> Bland.histogram(samples, bins: 10, label: "h", hatch: :diagonal)
        |> Bland.legend()
        |> Bland.to_svg()

      # Ten rectangles for the ten bins, plus page / frame / legend rects.
      n_rects = svg |> String.split("<rect ") |> length() |> Kernel.-(1)
      assert n_rects >= 10
      assert svg =~ "url(#bland-pattern-diagonal)"
    end
  end

  describe "Bland.Heatmap" do
    test "default_ramp returns a list of pattern atoms light to dark" do
      ramp = Bland.Heatmap.default_ramp()
      assert List.first(ramp) == :solid_white
      assert List.last(ramp) == :solid_black
    end

    test "ramp/1 samples the default ramp to exactly N levels" do
      assert length(Bland.Heatmap.ramp(3)) == 3
      assert length(Bland.Heatmap.ramp(7)) == 7
    end

    test "quantize clamps below/above range" do
      assert Bland.Heatmap.quantize(-5, {0, 10}, 5) == 0
      assert Bland.Heatmap.quantize(100, {0, 10}, 5) == 4
    end

    test "quantize distributes uniformly in range" do
      assert Bland.Heatmap.quantize(0, {0, 10}, 5) == 0
      assert Bland.Heatmap.quantize(9.9, {0, 10}, 5) == 4
    end

    test "extent walks a nested list" do
      assert Bland.Heatmap.extent([[1, 2, 3], [4, 5, 6]]) == {1, 6}
    end
  end

  describe "heatmap/3 and colorbar/2" do
    test "heatmap/3 stores data, edges, and defaults" do
      grid = [[1, 2], [3, 4]]

      fig =
        Bland.figure()
        |> Bland.heatmap(grid, label: "test", range: {0, 10})

      [%Bland.Series.Heatmap{data: ^grid, label: "test", range: {0, 10},
                             x_edges: xe, y_edges: ye}] = fig.series
      assert length(xe) == 3
      assert length(ye) == 3
    end

    test "custom x_edges and y_edges are preserved" do
      grid = [[1, 2, 3]]

      fig =
        Bland.figure()
        |> Bland.heatmap(grid, x_edges: [0.0, 1.0, 2.0, 3.0], y_edges: [0.0, 1.0])

      [%Bland.Series.Heatmap{x_edges: xe, y_edges: ye}] = fig.series
      assert xe == [0.0, 1.0, 2.0, 3.0]
      assert ye == [0.0, 1.0]
    end

    test "colorbar/2 attaches a map on the figure" do
      fig = Bland.figure() |> Bland.colorbar(position: :right, label: "T")
      assert fig.colorbar == %{position: :right, label: "T"}
    end

    test "renders a heatmap with colorbar" do
      grid =
        for j <- 0..9, into: [] do
          for i <- 0..9, into: [] do
            i + j * 1.0
          end
        end

      svg =
        Bland.figure(size: :square)
        |> Bland.heatmap(grid, label: "intensity")
        |> Bland.colorbar()
        |> Bland.to_svg()

      # One rect per cell plus framing rects (bg, border, frame, colorbar frame)
      assert svg =~ "url(#bland-pattern-diagonal)"
      # Colorbar labels should appear
      assert svg =~ "intensity"
    end
  end

  describe "Bland.Geo" do
    test "mercator maps equator to y=0" do
      {x, y} = Bland.Geo.mercator({0.0, 0.0})
      assert_in_delta x, 0.0, 1.0e-9
      assert_in_delta y, 0.0, 1.0e-9
    end

    test "mercator is symmetric about the equator" do
      {_, yn} = Bland.Geo.mercator({0.0, 45.0})
      {_, ys} = Bland.Geo.mercator({0.0, -45.0})
      assert_in_delta yn, -ys, 1.0e-9
    end

    test "mercator clamps poles to finite y" do
      {_, y_north} = Bland.Geo.mercator({0.0, 90.0})
      assert is_float(y_north)
      assert y_north < 1.0e6
    end

    test "equirect is identity" do
      assert Bland.Geo.equirect({10.0, 20.0}) == {10.0, 20.0}
    end

    test "project dispatches on projection atom" do
      assert Bland.Geo.project(:none, {3, 4}) == {3.0, 4.0}
      assert Bland.Geo.project(:equirect, {3, 4}) == {3.0, 4.0}

      {mx, _} = Bland.Geo.project(:mercator, {180.0, 0.0})
      assert_in_delta mx, :math.pi(), 1.0e-9
    end

    test "graticule generates meridian + parallel line pairs" do
      lines = Bland.Geo.graticule(lon_step: 90, lat_step: 45, lat_range: {-45, 45})
      assert length(lines) > 0
      assert Enum.all?(lines, fn {xs, ys} -> length(xs) == length(ys) end)
    end

    test "world_rect encloses the bbox" do
      {xs, ys} = Bland.Geo.world_rect({-10, 10}, {-5, 5}, 4)
      {x_min, x_max} = Enum.min_max(xs)
      {y_min, y_max} = Enum.min_max(ys)
      assert x_min == -10.0
      assert x_max == 10.0
      assert y_min == -5.0
      assert y_max == 5.0
    end
  end

  describe "figure projection" do
    test "figure accepts :projection field" do
      fig = Bland.figure(projection: :mercator)
      assert fig.projection == :mercator
    end

    test "renders a geo figure without errors" do
      svg =
        Bland.figure(size: :square, projection: :mercator,
          xlim: {-180, 180}, ylim: {-60, 60}, grid: :none)
        |> Bland.scatter([-74.0, 139.7, 0.0], [40.7, 35.7, 51.5], marker: :circle_filled)
        |> Bland.to_svg()

      assert svg =~ "<circle"
      # Three city circles should be visible
      circles = svg |> String.split("<circle") |> length() |> Kernel.-(1)
      assert circles >= 3
    end

    test "graticule/2 adds a bunch of dotted lines + labels" do
      fig =
        Bland.figure(projection: :mercator, xlim: {-180, 180}, ylim: {-80, 80})
        |> Bland.graticule(lon_step: 60, lat_step: 30)

      line_series = Enum.filter(fig.series, &match?(%Bland.Series.Line{}, &1))
      assert length(line_series) > 0
      # Default labels: true → at least one text annotation per meridian and parallel
      assert length(fig.annotations) > 0
    end

    test "projection: :none is the default and a no-op" do
      fig =
        Bland.figure()
        |> Bland.line([0, 1, 2], [0, 1, 4])

      assert fig.projection == :none
      # Output identical to if we hadn't set projection
      svg = Bland.to_svg(fig)
      assert svg =~ "<polyline"
    end
  end

  describe "Bland.polygon/4" do
    test "adds a polygon series" do
      fig = Bland.figure() |> Bland.polygon([0, 1, 1, 0], [0, 0, 1, 1], label: "square")
      [%Bland.Series.Polygon{xs: [0, 1, 1, 0], ys: [0, 0, 1, 1], label: "square"}] =
        fig.series
    end

    test "renders filled polygon with hatch" do
      svg =
        Bland.figure()
        |> Bland.polygon([0, 1, 0.5], [0, 0, 1], hatch: :diagonal, label: "tri")
        |> Bland.to_svg()

      assert svg =~ "<polygon"
      assert svg =~ "url(#bland-pattern-diagonal)"
    end

    test "stroke-only polygon has fill=none" do
      svg =
        Bland.figure()
        |> Bland.polygon([0, 1, 0.5], [0, 0, 1])
        |> Bland.to_svg()

      assert svg =~ ~s|fill="none"|
    end
  end

  describe "Bland.Basemaps" do
    test "layers/0 lists all available layer atoms" do
      layers = Bland.Basemaps.layers()
      assert :earth_coastlines in layers
      assert :earth_borders in layers
      assert :earth_tropics in layers
      assert :moon_maria in layers
    end

    test "features/1 returns features with name + points + closed?" do
      [first | _] = Bland.Basemaps.features(:earth_coastlines)
      assert is_binary(first.name)
      assert is_list(first.points)
      assert is_boolean(first.closed?)
      {lon, lat} = hd(first.points)
      assert is_float(lon)
      assert is_float(lat)
    end

    test "schematic coastlines include the named continents" do
      names =
        Bland.Basemaps.features(:earth_coastlines, :schematic)
        |> Enum.map(& &1.name)

      assert "Africa" in names
      assert "Eurasia" in names
      assert "North America" in names
      assert "South America" in names
      assert "Australia" in names
      assert "Antarctica" in names
    end

    test "schematic borders include major countries" do
      names =
        Bland.Basemaps.features(:earth_borders, :schematic)
        |> Enum.map(& &1.name)

      assert "USA (contiguous)" in names
      assert "Russia" in names
      assert "China" in names
      assert "Brazil" in names
    end

    test "low-res (Natural Earth 1:110m) coastlines have many segments" do
      features = Bland.Basemaps.features(:earth_coastlines, :low)
      assert length(features) > 50
      # Every NE coastline feature is unnamed "coastline" LineString
      assert Enum.all?(features, &(&1.name == "coastline"))
    end

    test "high-res (Natural Earth 1:50m) coastlines have even more segments" do
      low = Bland.Basemaps.features(:earth_coastlines, :low) |> length()
      high = Bland.Basemaps.features(:earth_coastlines, :high) |> length()
      assert high > low * 5
    end

    test "low-res borders name countries with Natural Earth ADMIN conventions" do
      names = Bland.Basemaps.features(:earth_borders, :low) |> Enum.map(& &1.name)
      assert "United States of America" in names
      assert "Russia" in names
      assert "China" in names
      assert "Brazil" in names
    end

    test "features/2 raises on unknown resolution" do
      assert_raise ArgumentError, fn ->
        Bland.Basemaps.features(:earth_coastlines, :nonexistent)
      end
    end

    test "moon maria include named lunar seas" do
      names = Bland.Basemaps.features(:moon_maria) |> Enum.map(& &1.name)
      assert "Mare Imbrium" in names
      assert "Mare Tranquillitatis" in names
      assert "Oceanus Procellarum" in names
    end

    test "closed features have first point == last point" do
      Bland.Basemaps.features(:earth_coastlines)
      |> Enum.filter(& &1.closed?)
      |> Enum.each(fn f ->
        assert List.first(f.points) == List.last(f.points),
               "#{f.name} is marked closed but first != last"
      end)
    end

    test "all feature coordinates are in valid lon/lat ranges" do
      for layer <- [:earth_coastlines, :earth_borders, :moon_maria] do
        for f <- Bland.Basemaps.features(layer),
            {lon, lat} <- f.points do
          assert lon >= -180.0 and lon <= 180.0,
                 "#{f.name} in #{layer} has out-of-range lon #{lon}"
          assert lat >= -90.0 and lat <= 90.0,
                 "#{f.name} in #{layer} has out-of-range lat #{lat}"
        end
      end
    end

    test "features/1 raises on unknown layer" do
      assert_raise ArgumentError, fn ->
        Bland.Basemaps.features(:nonexistent)
      end
    end

    test "unzip/1 pulls out {xs, ys}" do
      feature = %{name: "t", points: [{1.0, 2.0}, {3.0, 4.0}], closed?: false}
      assert Bland.Basemaps.unzip(feature) == {[1.0, 3.0], [2.0, 4.0]}
    end
  end

  describe "Bland.basemap/3" do
    test "adds coastline line series to a figure (low-res default)" do
      fig =
        Bland.figure(projection: :mercator, xlim: {-180, 180}, ylim: {-70, 75})
        |> Bland.basemap(:earth_coastlines)

      # NE coastlines are open LineStrings, so they render as Line series
      lines = Enum.filter(fig.series, &match?(%Bland.Series.Line{}, &1))
      assert length(lines) > 50
    end

    test "schematic coastlines render as Polygon series" do
      fig =
        Bland.figure(projection: :mercator, xlim: {-180, 180}, ylim: {-70, 75})
        |> Bland.basemap(:earth_coastlines, resolution: :schematic)

      polygons = Enum.filter(fig.series, &match?(%Bland.Series.Polygon{}, &1))
      assert length(polygons) > 5
    end

    test ":only filter narrows the feature set (schematic)" do
      fig =
        Bland.figure(projection: :mercator)
        |> Bland.basemap(:earth_coastlines, resolution: :schematic, only: ["Africa"])

      assert length(fig.series) == 1
    end

    test ":except filter removes features by name (schematic)" do
      all_count = length(Bland.Basemaps.features(:earth_coastlines, :schematic))

      fig =
        Bland.figure(projection: :mercator)
        |> Bland.basemap(:earth_coastlines,
             resolution: :schematic, except: ["Antarctica"])

      assert length(fig.series) == all_count - 1
    end

    test ":resolution: :high loads the 1:50m Natural Earth dataset" do
      fig =
        Bland.figure(projection: :mercator, xlim: {-180, 180}, ylim: {-70, 75})
        |> Bland.basemap(:earth_coastlines, resolution: :high)

      assert length(fig.series) > 1000
    end

    test ":hatch fills closed features with the pattern" do
      fig =
        Bland.figure(projection: :equirect)
        |> Bland.basemap(:moon_maria, hatch: :dots_sparse)

      assert Enum.all?(fig.series, fn
        %Bland.Series.Polygon{hatch: :dots_sparse} -> true
        _ -> false
      end)
    end

    test "tropics layer uses Line series (open features)" do
      fig =
        Bland.figure(projection: :mercator, xlim: {-180, 180}, ylim: {-80, 80})
        |> Bland.basemap(:earth_tropics, stroke: :dotted)

      assert Enum.all?(fig.series, &match?(%Bland.Series.Line{}, &1))
      assert length(fig.series) == 5
    end
  end

  describe "Bland.Patterns" do
    test "preset_cycle returns a non-empty list" do
      assert length(Bland.Patterns.preset_cycle()) > 5
    end

    test "cycle skips excluded patterns" do
      p = Bland.Patterns.cycle(0, [:solid_white])
      refute p == :solid_white
    end

    test "fill maps presets to url or color" do
      assert Bland.Patterns.fill(:solid_black) == "black"
      assert Bland.Patterns.fill(:solid_white) == "white"
      assert Bland.Patterns.fill(:diagonal) == "url(#bland-pattern-diagonal)"
    end

    test "defs emits a pattern per unique preset" do
      svg = Bland.Patterns.defs([:diagonal, :diagonal, :crosshatch]) |> IO.iodata_to_binary()
      assert String.contains?(svg, ~s|id="bland-pattern-diagonal"|)
      assert String.contains?(svg, ~s|id="bland-pattern-crosshatch"|)
      # Deduplicated — only one diagonal block
      assert length(String.split(svg, "bland-pattern-diagonal")) == 2
    end
  end

  describe "Bland.Svg" do
    test "escape handles XML special chars" do
      assert Bland.Svg.escape("<a & b>") == "&lt;a &amp; b&gt;"
    end

    test "num formats floats compactly" do
      assert Bland.Svg.num(1.0) == "1"
      assert Bland.Svg.num(1.2500) == "1.25"
      assert Bland.Svg.num(3) == "3"
    end
  end
end
