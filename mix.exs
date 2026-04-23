defmodule Bland.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/Stratogen-Applied-Research/bland"

  def project do
    [
      app: :bland,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Hex package name (`bland`) and module namespace (`Bland.*`) are
      # intentionally distinct: the library brand is BLAND (Elixir
      # Technical Drawing), shipped via the `bland` package.
      name: "Elixir Technical Drawing",
      description:
        "Pure-Elixir library for paper-ready, monochrome, hatch-patterned technical plots " <>
          "in the visual tradition of 1960s-80s engineering reports.",
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      # Used only by mix bland.basemaps.compile to parse Natural Earth
      # GeoJSON into the vendored Elixir data modules. The compiled
      # output has no JSON at runtime.
      {:jason, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      # The Natural Earth raw GeoJSON lives in priv/basemaps/source/ and
      # is NOT shipped in the Hex package — only the compiled Elixir
      # data modules under lib/bland/basemaps/data/ are. Users who want
      # to re-run `mix bland.basemaps.compile` clone the repo.
      files: ~w(lib mix.exs README.md LICENSE pages)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "pages/getting_started.md",
        "pages/patterns_and_hatching.md",
        "pages/styling_and_themes.md",
        "pages/paper_output.md",
        "notebooks/showcase.livemd"
      ],
      groups_for_extras: [
        Guides: ~r"pages/.*",
        Notebooks: ~r"notebooks/.*"
      ],
      groups_for_modules: [
        "Public API": [Bland, Bland.Figure, Bland.Theme],
        Rendering: [Bland.Renderer, Bland.Svg],
        Geometry: [Bland.Scale, Bland.Ticks],
        Styling: [Bland.Patterns, Bland.Markers, Bland.Strokes],
        Ornaments: [Bland.Legend, Bland.TitleBlock, Bland.Axes]
      ],
      source_ref: "v#{@version}"
    ]
  end
end
