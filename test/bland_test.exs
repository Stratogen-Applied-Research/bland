defmodule BlandTest do
  use ExUnit.Case, async: true
  doctest Bland.Scale
  doctest Bland.Ticks
  doctest Bland.Histogram

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
                             density: false}] = fig.series

      assert length(edges) == 5
      assert length(values) == 4
      assert Enum.sum(values) == length(samples)
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
      {edges, values, true} = Bland.Histogram.bin(samples, bins: 4, density: true)

      widths =
        edges
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [lo, hi] -> hi - lo end)

      total_area = Enum.zip(values, widths) |> Enum.map(fn {v, w} -> v * w end) |> Enum.sum()
      assert_in_delta total_area, 1.0, 1.0e-9
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
