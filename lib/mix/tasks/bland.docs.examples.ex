defmodule Mix.Tasks.Bland.Docs.Examples do
  @shortdoc "Renders a canonical set of example plots into pages/assets/"

  @moduledoc """
  Produces a fixed set of hero SVGs used by the generated documentation
  to illustrate each plot type.

  The output is committed to `pages/assets/`. ExDoc's `:assets` option
  copies that directory into the generated `doc/` tree so `![](assets/foo.svg)`
  markdown references resolve from both guide pages and module docs.

  Re-run after any rendering change that should be reflected in the
  docs:

      mix bland.docs.examples

  Every example is deterministic — the RNG is seeded so the images
  don't churn between commits.
  """

  use Mix.Task

  @output_dir "pages/assets"

  @impl Mix.Task
  def run(_args) do
    File.mkdir_p!(@output_dir)
    examples() |> Enum.each(&render/1)
    Mix.shell().info("Rendered #{length(examples())} SVG examples → #{@output_dir}")
  end

  defp render({name, fun}) do
    fig_or_svg = fun.()
    path = Path.join(@output_dir, "#{name}.svg")

    case fig_or_svg do
      %Bland.Figure{} = fig -> Bland.write!(fig, path)
      svg when is_binary(svg) -> File.write!(path, svg)
    end
  end

  # -------------------------------------------------------------------------
  # Example generators
  # -------------------------------------------------------------------------

  defp examples do
    [
      {"hero_line", &hero_line/0},
      {"hero_histogram", &hero_histogram/0},
      {"hero_bar_grouped", &hero_bar_grouped/0},
      {"hero_boxplot", &hero_boxplot/0},
      {"hero_scatter_area", &hero_scatter_area/0},
      {"hero_heatmap", &hero_heatmap/0},
      {"hero_contour", &hero_contour/0},
      {"hero_errorbar", &hero_errorbar/0},
      {"hero_stem", &hero_stem/0},
      {"hero_quiver", &hero_quiver/0},
      {"hero_qq", &hero_qq/0},
      {"hero_polar", &hero_polar/0},
      {"hero_smith", &hero_smith/0},
      {"hero_world", &hero_world/0},
      {"hero_moon", &hero_moon/0},
      {"hero_bode", &hero_bode/0},
      {"hero_subplots", &hero_subplots/0},
      {"hero_title_block", &hero_title_block/0}
    ]
  end

  defp hero_line do
    xs = Enum.map(0..100, &(&1 / 10.0))

    Bland.figure(size: {720, 440}, title: "Damped oscillation")
    |> Bland.axes(xlabel: "t [s]", ylabel: "x(t)", xlim: {0.0, 10.0}, ylim: {-1.1, 1.1})
    |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4) * :math.cos(&1))), label: "signal")
    |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4))), label: "envelope", stroke: :dashed)
    |> Bland.line(xs, Enum.map(xs, &(-:math.exp(-&1 / 4))), stroke: :dashed)
    |> Bland.hline(0.0, stroke: :dotted)
    |> Bland.legend(position: :top_right)
  end

  defp hero_histogram do
    :rand.seed(:exsss, {42, 17, 99})

    gaussianish = fn ->
      Enum.reduce(1..12, 0.0, fn _, acc -> acc + :rand.uniform() end) - 6.0
    end

    samples = Enum.map(1..5000, fn _ -> gaussianish.() end)

    Bland.figure(size: {720, 440}, title: "Sample distribution")
    |> Bland.axes(xlabel: "x", ylabel: "count")
    |> Bland.histogram(samples, bins: 40, label: "n = 5000", hatch: :diagonal)
    |> Bland.legend(position: :top_right)
  end

  defp hero_bar_grouped do
    cats = ["Jan", "Feb", "Mar", "Apr", "May", "Jun"]

    Bland.figure(size: {720, 440}, title: "Monthly throughput")
    |> Bland.axes(xlabel: "month", ylabel: "units / kcycle")
    |> Bland.bar(cats, [12, 18, 15, 22, 19, 25], label: "run A",
         hatch: :diagonal, group: :a)
    |> Bland.bar(cats, [9, 14, 18, 19, 22, 28], label: "run B",
         hatch: :crosshatch, group: :b)
    |> Bland.bar(cats, [10, 11, 13, 17, 20, 22], label: "run C",
         hatch: :dots_sparse, group: :c)
    |> Bland.legend(position: :top_left)
  end

  defp hero_boxplot do
    :rand.seed(:exsss, {11, 22, 33})
    control = Enum.map(1..100, fn _ -> :rand.normal(0, 1) end)
    treated = Enum.map(1..100, fn _ -> :rand.normal(1.2, 1.1) end) ++ [5.0, -4.5, 6.0]

    Bland.figure(size: {640, 440}, title: "Box plot")
    |> Bland.axes(ylabel: "response")
    |> Bland.boxplot([{"control", control}, {"treated", treated}],
         hatch: :diagonal, label: "n=100")
    |> Bland.legend(position: :top_left)
  end

  defp hero_scatter_area do
    :rand.seed(:exsss, {1, 2, 3})
    xs = Enum.map(0..50, &(&1 / 5.0))
    noisy = Enum.map(xs, fn x -> :math.sin(x) + (:rand.uniform() - 0.5) * 0.3 end)
    other = Enum.map(xs, fn x -> :math.cos(x) / 2 + (:rand.uniform() - 0.5) * 0.2 end)

    Bland.figure(size: {720, 440}, title: "Noisy observations")
    |> Bland.axes(xlabel: "x", ylabel: "y", ylim: {-1.5, 1.5})
    |> Bland.area(xs, Enum.map(xs, &:math.sin/1),
         baseline: 0.0, label: "sin(x) envelope", hatch: :diagonal)
    |> Bland.scatter(xs, noisy, label: "measurement A", marker: :circle_open)
    |> Bland.scatter(xs, other, label: "measurement B", marker: :cross)
    |> Bland.line(xs, Enum.map(xs, &:math.sin/1), stroke: :solid)
    |> Bland.line(xs, Enum.map(xs, &(:math.cos(&1) / 2)), stroke: :dashed)
    |> Bland.legend(position: :top_right, title: "Series")
  end

  defp hero_heatmap do
    grid =
      for j <- -10..9, into: [] do
        for i <- -10..9, into: [] do
          :math.exp(-(i * i + j * j) / 40)
        end
      end

    Bland.figure(size: {620, 620}, title: "2D Gaussian density")
    |> Bland.axes(xlabel: "x", ylabel: "y")
    |> Bland.heatmap(grid,
         x_edges: Enum.map(-10..10, &(&1 * 1.0)),
         y_edges: Enum.map(-10..10, &(&1 * 1.0)),
         label: "density")
    |> Bland.colorbar()
  end

  defp hero_contour do
    grid =
      for j <- -20..20, into: [] do
        for i <- -20..20, into: [] do
          :math.sin(i * 0.2) * :math.cos(j * 0.2)
        end
      end

    Bland.figure(size: {620, 620}, title: "Contours")
    |> Bland.axes(xlabel: "x", ylabel: "y")
    |> Bland.contour(grid,
         x_edges: Enum.map(-20..21, &(&1 * 0.1)),
         y_edges: Enum.map(-20..21, &(&1 * 0.1)),
         levels: [-0.8, -0.4, -0.1, 0.1, 0.4, 0.8])
  end

  defp hero_errorbar do
    :rand.seed(:exsss, {11, 22, 33})
    xs = Enum.to_list(1..10)
    ys = Enum.map(xs, fn x -> 0.5 * x + (:rand.uniform() - 0.5) end)
    yerr = Enum.map(xs, fn _ -> 0.2 + :rand.uniform() * 0.3 end)

    Bland.figure(size: {720, 440}, title: "Error bars")
    |> Bland.axes(xlabel: "x", ylabel: "y")
    |> Bland.errorbar(xs, ys, yerr: yerr, label: "y ± σ")
    |> Bland.legend(position: :top_left)
  end

  defp hero_stem do
    ns = Enum.to_list(0..20)
    vals = Enum.map(ns, fn n -> :math.cos(n * 0.5) * :math.exp(-n * 0.1) end)

    Bland.figure(size: {720, 440}, title: "Stem plot")
    |> Bland.axes(xlabel: "n", ylabel: "x[n]")
    |> Bland.stem(ns, vals, label: "x[n]")
    |> Bland.hline(0.0, stroke: :solid, stroke_width: 0.5)
    |> Bland.legend(position: :top_right)
  end

  defp hero_quiver do
    qxs = for i <- -2..2, _ <- -2..2, do: i * 1.0
    qys = for _ <- -2..2, j <- -2..2, do: j * 1.0
    qus = Enum.map(qys, &(-&1 * 0.3))
    qvs = Enum.map(qxs, &(&1 * 0.3))

    Bland.figure(size: {560, 560}, title: "Rotation field")
    |> Bland.axes(xlabel: "x", ylabel: "y", xlim: {-3, 3}, ylim: {-3, 3})
    |> Bland.quiver(qxs, qys, qus, qvs)
  end

  defp hero_qq do
    :rand.seed(:exsss, {44, 66, 88})
    samples = Enum.map(1..200, fn _ -> :rand.normal(0, 1) end)

    Bland.figure(size: {560, 560}, title: "Q-Q normal")
    |> Bland.axes(xlabel: "theoretical quantile", ylabel: "sample quantile")
    |> Bland.qq_plot(samples, label: "n=200")
    |> Bland.legend(position: :top_left)
  end

  defp hero_polar do
    thetas = Enum.map(0..360, fn d -> d * :math.pi() / 180 end)
    cardioid = Enum.map(thetas, fn t -> 0.5 * (1 + :math.cos(t)) end)
    lobes = Enum.map(thetas, fn t -> abs(:math.cos(3 * t)) * 0.9 end)

    Bland.polar_figure(size: {560, 560}, rmax: 1.0, title: "Polar")
    |> Bland.polar_grid(r_ticks: [0.25, 0.5, 0.75, 1.0], theta_step: 30)
    |> Bland.line(thetas, cardioid, stroke: :solid, label: "cardioid")
    |> Bland.line(thetas, lobes, stroke: :dashed, label: "|cos 3θ|")
    |> Bland.legend(position: :top_right)
  end

  defp hero_smith do
    gammas =
      for i <- 0..60 do
        t = i / 60.0
        r = 0.5 + 1.5 * t
        x = :math.sin(t * 3.0 * :math.pi()) * 0.8
        Bland.Smith.gamma_from_z({r, x})
      end

    {gx, gy} = Enum.unzip(gammas)

    Bland.smith_figure(size: {620, 620}, title: "S₁₁ sweep")
    |> Bland.smith_grid()
    |> Bland.line(gx, gy, stroke: :solid, stroke_width: 1.4, label: "S₁₁")
    |> Bland.scatter([List.first(gx)], [List.first(gy)],
         marker: :circle_filled, marker_size: 5, label: "start")
    |> Bland.scatter([List.last(gx)], [List.last(gy)],
         marker: :cross, marker_size: 6, label: "end")
    |> Bland.legend(position: :bottom_right)
  end

  defp hero_world do
    Bland.figure(size: {1000, 560}, projection: :mercator,
      title: "World basemap",
      xlim: {-180, 180}, ylim: {-65, 78})
    |> Bland.basemap(:earth_coastlines, stroke_width: 0.6)
    |> Bland.basemap(:earth_borders, stroke: :dashed, stroke_width: 0.3)
    |> Bland.basemap(:earth_tropics, stroke: :dotted)
  end

  defp hero_moon do
    apollo = [
      {"A11", 23.47, 0.67},
      {"A12", -23.42, -3.01},
      {"A14", -17.47, -3.65},
      {"A15", 3.63, 26.13},
      {"A16", 15.50, -8.97},
      {"A17", 30.77, 20.19}
    ]

    lons = Enum.map(apollo, fn {_, l, _} -> l end)
    lats = Enum.map(apollo, fn {_, _, l} -> l end)

    fig =
      Bland.figure(size: {680, 560}, projection: :equirect,
        title: "Apollo landing sites",
        xlim: {-55, 55}, ylim: {-25, 40}, grid: :none)
      |> Bland.graticule(lon_step: 15, lat_step: 15,
           lon_range: {-60, 60}, lat_range: {-30, 45}, labels: false)
      |> Bland.basemap(:moon_maria, hatch: :dots_sparse)
      |> Bland.scatter(lons, lats, marker: :cross, marker_size: 7, label: "Apollo")
      |> Bland.legend(position: :bottom_right)

    Enum.reduce(apollo, fig, fn {n, lon, lat}, acc ->
      Bland.annotate(acc, text: n, at: {lon + 1.5, lat + 1.5}, font_size: 9)
    end)
  end

  defp hero_bode do
    omegas = Enum.map(-20..40, fn k -> :math.pow(10, k / 10.0) end)

    tf = fn w ->
      denom = 1 + w * w / 100
      {1 / denom, -(w / 10) / denom}
    end

    Bland.bode(omegas, tf,
      title: "First-order lowpass",
      xlabel: "ω [rad/s]",
      cell_width: 780,
      cell_height: 260
    )
  end

  defp hero_subplots do
    xs = Enum.map(0..100, &(&1 / 10.0))

    raw =
      Bland.figure(size: {500, 280}, title: "Raw signal")
      |> Bland.axes(xlabel: "t [s]", ylabel: "x(t)")
      |> Bland.line(xs, Enum.map(xs, &(:math.cos(&1) + :math.sin(&1 * 3) * 0.3)))

    env =
      Bland.figure(size: {500, 280}, title: "Envelope")
      |> Bland.axes(xlabel: "t [s]", ylabel: "|x(t)|")
      |> Bland.line(xs,
           Enum.map(xs, &abs(:math.cos(&1) + :math.sin(&1 * 3) * 0.3)))

    Bland.grid([raw, env], columns: 2, cell_width: 500, cell_height: 280,
      title: "Subplots")
  end

  defp hero_title_block do
    xs = Enum.map(0..100, &(&1 / 10.0))

    Bland.figure(size: :a5_landscape,
      title: "Figure 1 — Damped response")
    |> Bland.axes(xlabel: "time [s]", ylabel: "amplitude",
         xlim: {0.0, 10.0}, ylim: {-1.1, 1.1})
    |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4) * :math.cos(&1))),
         label: "signal")
    |> Bland.line(xs, Enum.map(xs, &(:math.exp(-&1 / 4))),
         label: "envelope", stroke: :dashed)
    |> Bland.line(xs, Enum.map(xs, &(-:math.exp(-&1 / 4))), stroke: :dashed)
    |> Bland.hline(0.0, stroke: :dotted)
    |> Bland.legend(position: :top_right)
    |> Bland.title_block(
      project: "Project BLAND",
      title: "Damped oscillation",
      drawn_by: "JM",
      checked_by: "RK",
      date: "2026-04-22",
      rev: "A",
      scale: "1:1",
      sheet: "1 of 1"
    )
  end
end
