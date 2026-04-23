defmodule Bland.Basemaps.Earth do
  @moduledoc """
  Hand-curated, low-resolution Earth coastline, border, and reference
  line data.

  All coordinates are `{longitude_deg, latitude_deg}`. Continental
  outlines are closed polygons (first point == last point) traced
  roughly clockwise. They have enough detail to be recognizable at
  world scale and *not more* — this is a schematic data set, not a
  cartographic one.
  """

  @type feature :: %{name: String.t(), points: [{float(), float()}], closed?: boolean()}

  # =========================================================================
  # Coastlines
  # =========================================================================
  #
  # Continents traced clockwise starting from a prominent headland. Major
  # islands as separate closed features. Antarctica is cut off at 70°S
  # (a full traverse of the coast would overwhelm the total point count).

  @africa [
    # N coast — Mediterranean, Morocco → Tunisia → Libya → Egypt
    {-5.5, 35.9}, {-1.5, 35.5}, {3.0, 36.7}, {9.0, 37.2}, {11.0, 36.8},
    {15.0, 33.0}, {19.5, 31.0}, {23.5, 32.5}, {29.0, 31.2}, {32.5, 31.3},
    # Red Sea W coast — Suez → Port Sudan → Eritrea → Gulf of Aden
    {33.5, 27.5}, {36.5, 22.0}, {38.5, 17.5}, {39.5, 15.0}, {42.5, 13.0},
    # Horn of Africa
    {43.5, 11.5}, {51.4, 11.8}, {51.0, 10.4},
    # E coast — Somalia → Kenya → Mozambique → Cape
    {50.0, 3.0}, {45.5, -1.0}, {40.5, -6.0}, {40.0, -11.5},
    {40.5, -16.0}, {36.0, -21.0}, {34.5, -26.5}, {32.5, -29.0},
    {30.5, -31.5}, {27.0, -33.5}, {22.5, -34.5}, {18.5, -34.4},
    # W coast — Namibia → Angola → Gulf of Guinea → Senegal
    {15.0, -28.5}, {12.5, -15.5}, {13.5, -8.0}, {12.0, -5.0},
    {9.5, -1.0}, {9.5, 2.0}, {7.0, 4.5}, {3.5, 6.5}, {-1.0, 5.5},
    {-6.5, 4.5}, {-11.0, 6.5}, {-13.5, 9.5}, {-16.5, 13.5},
    {-17.0, 16.0}, {-17.0, 21.0}, {-13.5, 27.5}, {-10.0, 30.5},
    {-9.0, 32.5}, {-5.5, 35.9}
  ]

  @eurasia [
    # Iberian/W European coast — Gibraltar → Portugal → Bay of Biscay →
    # Brittany → Channel → Denmark → Scandinavia
    {-5.5, 36.0}, {-9.5, 38.5}, {-9.0, 43.0}, {-2.0, 43.5},
    {-4.5, 48.5}, {2.0, 51.0}, {4.0, 52.0}, {7.5, 53.5},
    {9.5, 54.5}, {13.0, 55.5}, {18.0, 57.5},
    # Scandinavia — S Sweden → North Cape → Kola → White Sea
    {18.0, 62.0}, {22.0, 65.5}, {25.0, 71.0}, {40.0, 67.0}, {42.0, 66.5},
    # Arctic Russian coast — very abbreviated
    {55.0, 71.0}, {75.0, 72.0}, {100.0, 73.5}, {130.0, 72.5},
    {160.0, 69.5}, {180.0, 68.5},
    # NE Asia Pacific — Chukchi → Kamchatka → Sea of Okhotsk
    {175.0, 65.0}, {163.0, 59.0}, {157.0, 51.0}, {142.0, 46.0},
    # Japan-facing coast → Korea → Yellow Sea
    {138.0, 41.5}, {131.0, 43.0}, {130.0, 35.0}, {124.0, 40.0},
    {121.5, 38.0}, {119.5, 35.0}, {121.0, 31.5},
    # China E coast → Vietnam → Malay Peninsula
    {121.5, 28.0}, {118.0, 23.5}, {112.0, 21.5}, {108.0, 18.0},
    {106.5, 10.5}, {103.5, 1.5},
    # Bay of Bengal → India → Arabian Sea → Persian Gulf
    {98.5, 8.5}, {91.0, 22.5}, {80.0, 15.0}, {77.5, 8.0},
    {72.5, 17.5}, {68.0, 23.5}, {61.0, 25.0}, {57.5, 24.0},
    {51.5, 25.0}, {48.0, 30.0},
    # Arabian Peninsula — Persian Gulf → Oman → Yemen → Red Sea
    {56.0, 26.5}, {58.0, 23.5}, {55.5, 17.5}, {52.5, 14.5},
    {45.0, 13.0}, {43.0, 13.5}, {38.5, 21.0}, {34.5, 28.0},
    # Eastern Mediterranean → Turkey → Greece → Italy → Iberia
    {34.5, 31.0}, {35.5, 35.0}, {33.0, 36.0}, {29.0, 37.0},
    {26.5, 38.5}, {23.5, 38.5}, {20.0, 40.0}, {18.0, 40.0},
    {13.5, 45.5}, {12.0, 44.5}, {8.5, 44.0}, {4.0, 43.5},
    {3.0, 42.5}, {-5.5, 36.0}
  ]

  @north_america [
    # Atlantic/Canadian coast — St. Lawrence → Labrador → Baffin → Arctic
    {-55.0, 50.0}, {-60.0, 56.0}, {-62.0, 60.0}, {-70.0, 63.0},
    {-79.0, 73.0}, {-90.0, 73.0}, {-110.0, 71.0}, {-125.0, 70.0},
    {-141.0, 70.0},
    # Alaska → Bering → Aleutian Peninsula base
    {-155.0, 71.0}, {-165.0, 66.0}, {-168.0, 60.0}, {-162.0, 54.5},
    {-150.0, 60.5}, {-135.0, 58.0}, {-131.0, 54.5},
    # Pacific Canadian → US → Baja California
    {-124.5, 49.0}, {-124.0, 40.0}, {-118.0, 34.0}, {-117.5, 32.5},
    {-112.5, 31.5}, {-109.0, 22.5}, {-115.0, 29.0},
    # Gulf of California → mainland Mexico → Central America
    {-107.5, 22.5}, {-106.0, 21.5}, {-98.5, 16.5}, {-92.5, 14.5},
    {-87.5, 13.0}, {-83.5, 8.0}, {-80.0, 8.5},
    # Caribbean coast / Panama → Central America Atlantic → Gulf of Mexico
    {-82.5, 9.5}, {-84.0, 14.0}, {-88.0, 15.5}, {-90.5, 18.5},
    {-95.5, 18.5}, {-97.5, 25.5}, {-94.0, 29.5}, {-89.5, 30.0},
    {-83.0, 29.5}, {-82.5, 24.5}, {-80.5, 25.0}, {-81.5, 31.0},
    # US Atlantic → Canadian Maritimes → Newfoundland → back to start
    {-76.0, 35.0}, {-74.5, 40.5}, {-70.0, 41.5}, {-66.5, 45.0},
    {-60.5, 46.5}, {-53.5, 47.0}, {-55.0, 50.0}
  ]

  @south_america [
    # Caribbean NE corner → Venezuela → Guyanas → Brazil NE point → S coast
    {-61.5, 10.5}, {-52.0, 5.0}, {-48.0, -1.0}, {-35.0, -5.5},
    {-38.5, -13.5}, {-41.0, -22.5}, {-43.5, -23.0},
    {-48.5, -26.5}, {-53.0, -33.5}, {-57.5, -38.5}, {-63.5, -40.5},
    {-65.5, -45.0}, {-68.5, -52.5}, {-70.5, -54.5},
    # Tierra del Fuego → Pacific coast Chile → Peru → Ecuador
    {-75.0, -52.0}, {-75.0, -48.5}, {-72.0, -42.0}, {-72.5, -36.0},
    {-71.5, -30.0}, {-70.5, -23.0}, {-70.5, -18.0}, {-76.5, -13.5},
    {-79.5, -8.5}, {-81.0, -6.0}, {-80.5, -2.0}, {-79.5, 1.0},
    # Colombia Pacific → Panama → Caribbean coast
    {-78.0, 5.5}, {-77.0, 8.5}, {-75.5, 10.5}, {-71.0, 12.5},
    {-61.5, 10.5}
  ]

  @australia [
    {114.0, -22.0}, {114.5, -27.0}, {115.5, -32.0}, {117.5, -35.0},
    {121.0, -33.5}, {127.0, -32.0}, {131.5, -31.5}, {137.0, -35.0},
    {140.0, -37.5}, {144.0, -38.5}, {148.0, -37.5}, {150.0, -37.5},
    {151.5, -33.0}, {153.5, -28.5}, {153.0, -25.0}, {149.5, -22.0},
    {145.5, -15.0}, {142.5, -10.5}, {138.0, -15.5}, {135.5, -15.0},
    {130.0, -12.0}, {125.0, -14.5}, {122.0, -17.0}, {119.0, -20.0},
    {114.0, -22.0}
  ]

  @antarctica_simplified [
    # Only a coarse outline at ~70–75°S; continuing south would need far
    # more points to avoid degenerate geometry at the pole.
    {-180.0, -75.0}, {-150.0, -74.0}, {-120.0, -73.0}, {-90.0, -72.5},
    {-60.0, -70.5}, {-40.0, -71.5}, {-20.0, -73.5}, {0.0, -70.5},
    {30.0, -69.5}, {60.0, -68.5}, {90.0, -66.5}, {120.0, -67.0},
    {150.0, -70.0}, {170.0, -72.0}, {180.0, -75.0}
  ]

  @greenland [
    {-54.0, 83.0}, {-22.0, 82.0}, {-18.0, 75.0}, {-20.0, 70.5},
    {-25.0, 68.5}, {-37.0, 65.0}, {-44.0, 60.0}, {-50.0, 63.0},
    {-53.0, 66.5}, {-54.5, 70.0}, {-56.0, 73.5}, {-63.0, 76.5},
    {-72.0, 79.0}, {-65.0, 82.0}, {-54.0, 83.0}
  ]

  @great_britain [
    # Rough outline of Britain + Ireland traced clockwise, with both
    # islands simplified into a single polyline cluster (separate
    # polygons below).
    {1.5, 52.0}, {1.7, 52.8}, {0.5, 53.5}, {-0.2, 54.5}, {-1.2, 55.0},
    {-2.0, 57.5}, {-3.0, 58.5}, {-5.0, 58.5}, {-5.5, 56.5}, {-4.8, 55.0},
    {-5.0, 54.5}, {-3.2, 53.5}, {-4.5, 52.0}, {-5.0, 51.5}, {-3.3, 50.7},
    {-0.2, 50.7}, {0.8, 51.0}, {1.5, 52.0}
  ]

  @ireland [
    {-6.0, 55.0}, {-7.5, 55.0}, {-10.0, 54.5}, {-10.5, 52.0},
    {-9.5, 51.5}, {-6.5, 51.5}, {-6.3, 52.2}, {-6.0, 55.0}
  ]

  @japan [
    # Honshu, simplified
    {140.5, 41.5}, {141.5, 39.0}, {141.5, 38.5}, {141.0, 36.0},
    {140.0, 35.0}, {139.5, 34.0}, {136.0, 34.0}, {133.0, 34.5},
    {130.8, 33.5}, {130.5, 34.5}, {131.5, 35.5}, {133.5, 36.0},
    {135.5, 35.5}, {136.5, 37.0}, {138.5, 37.5}, {140.5, 41.5}
  ]

  @madagascar [
    {50.0, -16.0}, {50.5, -20.0}, {48.5, -25.5}, {45.0, -25.5},
    {44.0, -21.0}, {44.0, -16.0}, {46.5, -15.5}, {49.5, -12.0},
    {50.0, -16.0}
  ]

  @iceland [
    {-14.0, 66.0}, {-14.0, 64.5}, {-18.0, 63.5}, {-22.5, 64.0},
    {-24.0, 65.5}, {-21.5, 66.5}, {-16.5, 66.5}, {-14.0, 66.0}
  ]

  @new_zealand_north [
    {173.0, -34.5}, {175.0, -36.5}, {178.5, -37.5}, {177.0, -39.5},
    {174.0, -41.5}, {174.5, -40.0}, {173.0, -34.5}
  ]

  @new_zealand_south [
    {166.5, -45.5}, {168.5, -46.5}, {171.5, -44.5}, {174.0, -41.5},
    {170.5, -43.0}, {167.0, -43.5}, {166.5, -45.5}
  ]

  @cuba [
    {-74.5, 20.5}, {-77.5, 21.5}, {-82.0, 23.0}, {-84.5, 22.0},
    {-82.0, 22.5}, {-78.0, 21.5}, {-74.5, 20.5}
  ]

  @coastline_features [
    {"Africa", @africa, true},
    {"Eurasia", @eurasia, true},
    {"North America", @north_america, true},
    {"South America", @south_america, true},
    {"Australia", @australia, true},
    {"Antarctica", @antarctica_simplified, false},
    {"Greenland", @greenland, true},
    {"Great Britain", @great_britain, true},
    {"Ireland", @ireland, true},
    {"Japan", @japan, true},
    {"Madagascar", @madagascar, true},
    {"Iceland", @iceland, true},
    {"New Zealand (N)", @new_zealand_north, true},
    {"New Zealand (S)", @new_zealand_south, true},
    {"Cuba", @cuba, true}
  ]

  @doc """
  Returns the list of coastline features at the requested resolution.

  ## Resolutions

    * `:low`       — Natural Earth 1:110m (default). ~130 features,
      ~5k points, ~90 KB compiled.
    * `:high`      — Natural Earth 1:50m. ~1,400 features, ~60k points,
      ~1 MB compiled.
    * `:schematic` — the hand-curated continental outlines shipped with
      BLAND 0.1 (15 features). Useful when you want a deliberately
      rough, "drawn by a draftsman" look.

  All three datasets share the same feature-map shape:
  `%{name: String.t(), points: [{lon, lat}], closed?: bool}`.
  """
  @spec coastlines(:low | :high | :schematic) :: [Bland.Basemaps.feature()]
  def coastlines(resolution \\ :low)

  def coastlines(:schematic) do
    Enum.map(@coastline_features, fn {name, pts, closed?} ->
      %{name: name, points: normalize(pts, closed?), closed?: closed?}
    end)
  end

  def coastlines(:low), do: Bland.Basemaps.Data.Coastline110m.features()
  def coastlines(:high), do: Bland.Basemaps.Data.Coastline50m.features()

  def coastlines(other),
    do:
      raise(ArgumentError,
        "unknown coastline resolution #{inspect(other)}; expected :low, :high, or :schematic"
      )

  # =========================================================================
  # Political borders
  # =========================================================================
  #
  # Only a handful of illustrative national outlines — enough to annotate
  # a world map without pretending to be a cartographic reference. Each
  # outline is a closed polygon.

  @usa_contiguous [
    {-125.0, 49.0}, {-125.0, 42.5}, {-124.0, 40.0}, {-120.5, 34.5},
    {-117.5, 32.7}, {-111.0, 31.5}, {-108.0, 31.5}, {-106.5, 32.0},
    {-103.0, 29.0}, {-99.5, 27.5}, {-97.5, 26.0}, {-94.0, 29.5},
    {-89.0, 30.0}, {-85.5, 29.0}, {-82.0, 24.5}, {-80.0, 25.0},
    {-80.5, 32.0}, {-76.0, 36.5}, {-74.0, 40.5}, {-70.0, 42.5},
    {-67.0, 45.0}, {-69.0, 47.5}, {-75.0, 45.0}, {-82.5, 45.5},
    {-88.5, 48.0}, {-95.0, 49.0}, {-125.0, 49.0}
  ]

  @canada [
    {-140.5, 60.0}, {-140.5, 70.0}, {-130.0, 70.0}, {-110.0, 71.0},
    {-95.0, 73.5}, {-78.0, 73.5}, {-70.0, 63.0}, {-63.0, 60.0},
    {-57.0, 52.5}, {-53.0, 47.5}, {-60.0, 46.5}, {-67.0, 45.0},
    {-69.0, 47.5}, {-75.0, 45.0}, {-82.5, 45.5}, {-88.5, 48.0},
    {-95.0, 49.0}, {-123.0, 49.0}, {-132.0, 54.5}, {-140.5, 60.0}
  ]

  @mexico [
    {-117.5, 32.7}, {-111.0, 31.5}, {-108.0, 31.5}, {-106.5, 32.0},
    {-103.0, 29.0}, {-99.5, 27.5}, {-97.5, 26.0}, {-94.0, 18.5},
    {-91.5, 18.5}, {-88.0, 21.5}, {-87.0, 21.5}, {-89.0, 17.5},
    {-92.0, 15.0}, {-94.5, 16.0}, {-96.5, 15.5}, {-100.5, 17.0},
    {-103.5, 18.5}, {-105.5, 20.5}, {-106.5, 23.5}, {-109.0, 23.0},
    {-109.5, 25.0}, {-112.5, 31.0}, {-115.0, 32.5}, {-117.5, 32.7}
  ]

  @brazil [
    {-35.0, -5.5}, {-40.0, -22.5}, {-48.5, -25.5}, {-53.5, -33.5},
    {-57.5, -30.5}, {-58.0, -20.0}, {-58.5, -16.5}, {-62.5, -11.0},
    {-68.5, -11.0}, {-70.5, -9.5}, {-72.5, -7.5}, {-73.5, -4.5},
    {-70.0, -4.0}, {-69.5, -1.0}, {-67.0, 1.5}, {-61.5, 4.5},
    {-59.5, 4.5}, {-52.0, 5.0}, {-48.0, -1.0}, {-35.0, -5.5}
  ]

  @russia_simplified [
    # Russia is hard to outline at this detail, so this is a very
    # loose bounding-outline — Kaliningrad excluded, southern steppe
    # border simplified.
    {28.0, 60.0}, {28.5, 70.0}, {40.0, 71.0}, {60.0, 72.0},
    {80.0, 73.0}, {100.0, 73.5}, {130.0, 73.0}, {160.0, 70.0},
    {180.0, 68.5}, {180.0, 65.0}, {160.0, 60.0}, {142.0, 54.0},
    {135.0, 48.5}, {128.0, 45.0}, {120.0, 50.0}, {108.0, 51.5},
    {95.0, 50.0}, {83.0, 51.5}, {68.0, 55.0}, {55.0, 51.5},
    {47.0, 48.5}, {42.0, 45.0}, {37.0, 45.5}, {28.0, 54.0},
    {28.0, 60.0}
  ]

  @china_simplified [
    {135.0, 48.5}, {128.0, 45.0}, {124.0, 40.0}, {121.0, 38.5},
    {121.5, 34.0}, {121.5, 28.0}, {118.0, 23.5}, {113.5, 22.0},
    {110.0, 21.5}, {108.0, 21.0}, {105.0, 21.5}, {101.5, 22.0},
    {97.5, 22.0}, {95.0, 28.5}, {92.0, 29.0}, {88.5, 28.0},
    {80.5, 30.5}, {74.0, 38.0}, {80.0, 42.5}, {85.0, 47.5},
    {91.0, 46.5}, {95.0, 44.5}, {100.0, 42.5}, {110.0, 42.5},
    {116.5, 43.5}, {120.0, 50.0}, {127.5, 50.0}, {135.0, 48.5}
  ]

  @india [
    {77.5, 8.0}, {79.0, 9.0}, {80.5, 13.0}, {81.5, 17.0},
    {84.5, 19.5}, {87.0, 21.5}, {89.0, 22.0}, {89.5, 26.5},
    {88.0, 27.0}, {80.0, 28.5}, {78.5, 31.0}, {75.0, 32.5},
    {77.0, 35.5}, {74.0, 34.5}, {69.5, 28.0}, {68.0, 24.0},
    {70.0, 22.5}, {71.5, 21.0}, {72.5, 17.5}, {74.0, 14.5},
    {76.0, 10.0}, {77.5, 8.0}
  ]

  @france [
    {-1.5, 49.5}, {2.5, 51.0}, {5.5, 49.5}, {8.0, 48.5},
    {7.5, 47.5}, {6.5, 45.5}, {7.5, 43.7}, {3.0, 42.5},
    {0.0, 42.7}, {-1.7, 43.5}, {-1.7, 46.5}, {-4.5, 48.5},
    {-1.5, 49.5}
  ]

  @germany [
    {6.0, 53.5}, {9.5, 54.5}, {13.5, 54.0}, {14.5, 51.0},
    {12.5, 50.5}, {13.5, 48.5}, {10.0, 47.5}, {7.5, 47.5},
    {6.0, 49.5}, {6.0, 51.5}, {6.0, 53.5}
  ]

  @australia_border [
    # Australia's political border and coast coincide.
    {114.0, -22.0}, {114.5, -27.0}, {115.5, -32.0}, {117.5, -35.0},
    {121.0, -33.5}, {127.0, -32.0}, {131.5, -31.5}, {137.0, -35.0},
    {140.0, -37.5}, {144.0, -38.5}, {148.0, -37.5}, {150.0, -37.5},
    {151.5, -33.0}, {153.5, -28.5}, {153.0, -25.0}, {149.5, -22.0},
    {145.5, -15.0}, {142.5, -10.5}, {138.0, -15.5}, {135.5, -15.0},
    {130.0, -12.0}, {125.0, -14.5}, {122.0, -17.0}, {119.0, -20.0},
    {114.0, -22.0}
  ]

  @border_features [
    {"USA (contiguous)", @usa_contiguous},
    {"Canada", @canada},
    {"Mexico", @mexico},
    {"Brazil", @brazil},
    {"Russia", @russia_simplified},
    {"China", @china_simplified},
    {"India", @india},
    {"France", @france},
    {"Germany", @germany},
    {"Australia", @australia_border}
  ]

  @doc """
  Returns the list of political border features at the requested
  resolution.

    * `:low`       — Natural Earth 1:110m (default). 177 sovereign
      polygons, ~10k points, ~180 KB compiled.
    * `:high`      — Natural Earth 1:50m. ~240 polygons (including
      disputed areas), ~100k points, ~1.6 MB compiled.
    * `:schematic` — the 10 hand-curated national outlines shipped
      with BLAND 0.1.
  """
  @spec borders(:low | :high | :schematic) :: [Bland.Basemaps.feature()]
  def borders(resolution \\ :low)

  def borders(:schematic) do
    Enum.map(@border_features, fn {name, pts} ->
      %{name: name, points: normalize(pts, true), closed?: true}
    end)
  end

  def borders(:low), do: Bland.Basemaps.Data.Countries110m.features()
  def borders(:high), do: Bland.Basemaps.Data.Countries50m.features()

  def borders(other),
    do:
      raise(ArgumentError,
        "unknown border resolution #{inspect(other)}; expected :low, :high, or :schematic"
      )

  # =========================================================================
  # Tropics and reference lines
  # =========================================================================

  @reference_lines [
    {"Arctic Circle", 66.5},
    {"Tropic of Cancer", 23.4},
    {"Equator", 0.0},
    {"Tropic of Capricorn", -23.4},
    {"Antarctic Circle", -66.5}
  ]

  @doc """
  Returns the standard reference parallels as open polylines spanning
  lon ∈ [-180, 180]. Useful as dashed or dotted overlay lines.
  """
  @spec tropics() :: [Bland.Basemaps.feature()]
  def tropics do
    Enum.map(@reference_lines, fn {name, lat} ->
      %{
        name: name,
        points: [{-180.0, lat}, {180.0, lat}],
        closed?: false
      }
    end)
  end

  # =========================================================================
  # Helpers
  # =========================================================================

  defp normalize(points, closed?) do
    pts = Enum.map(points, fn {lon, lat} -> {lon * 1.0, lat * 1.0} end)

    if closed? do
      case {List.first(pts), List.last(pts)} do
        {first, last} when first == last -> pts
        _ -> pts ++ [List.first(pts)]
      end
    else
      pts
    end
  end
end
