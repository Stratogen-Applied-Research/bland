defmodule Bland.Basemaps.Moon do
  @moduledoc """
  Hand-curated outlines of the major lunar maria (basaltic plains of
  the Moon's near side).

  Coordinates are selenographic `{longitude_deg, latitude_deg}`, using
  the convention where east is positive and west is negative — matching
  the modern IAU standard and most contemporary lunar atlases.

  All mare outlines are closed polygons, roughly traced from the
  lithological boundary visible in telescopic imagery. These are
  *schematic* — they capture the shape and approximate extent of each
  mare but not the coastline detail visible under high magnification.

  ## Maria included

  | Mare              | Approximate center | Notes                        |
  | ----------------- | ------------------ | ---------------------------- |
  | Imbrium           | 33°N, 17°W         | Largest impact basin mare    |
  | Serenitatis       | 28°N, 17°E         | Apollo 17 landing area       |
  | Tranquillitatis   | 8°N, 31°E          | Apollo 11 landing area       |
  | Crisium           | 17°N, 59°E         | Isolated circular mare       |
  | Fecunditatis      | -8°N, 51°E         | Irregular southeast basin    |
  | Nectaris          | -15°N, 35°E        | Small southeast basin        |
  | Nubium            | -21°N, -17°W       | Southwest highlands border   |
  | Humorum           | -24°N, -39°W       | Small circular mare          |
  | Frigoris          | 56°N, -15°W        | Elongated northern band      |
  | Procellarum       | 20°N, -55°W        | Huge western "ocean"         |
  | Cognitum          | -10°N, -23°W       | Small mare, Surveyor 3 site  |
  | Vaporum           | 13°N, 4°E          | Small equatorial mare        |

  The northwest-negative / east-positive convention means that Mare
  Imbrium's center (`-17°W longitude`) appears as `-17` in the data.
  """

  # Imbrium — the largest near-side impact basin; roughly circular
  @imbrium [
    {-30.0, 28.0}, {-27.0, 32.0}, {-22.0, 37.0}, {-15.0, 41.0},
    {-6.0, 41.5}, {0.0, 39.0}, {5.0, 36.0}, {6.5, 32.0},
    {3.0, 26.5}, {-4.0, 23.5}, {-12.0, 21.5}, {-20.0, 22.5},
    {-27.0, 25.0}, {-30.0, 28.0}
  ]

  @serenitatis [
    {7.0, 17.0}, {10.0, 21.0}, {15.0, 26.0}, {20.0, 31.5},
    {26.0, 33.0}, {30.0, 30.5}, {30.0, 26.0}, {28.0, 20.5},
    {24.0, 17.0}, {18.0, 15.0}, {12.0, 15.5}, {7.0, 17.0}
  ]

  @tranquillitatis [
    {22.0, 13.0}, {21.0, 17.0}, {23.0, 19.5}, {27.0, 20.5},
    {32.0, 18.5}, {36.0, 14.5}, {39.0, 10.0}, {40.0, 4.5},
    {37.5, 0.0}, {32.0, -1.5}, {26.0, -0.5}, {22.0, 2.5},
    {21.0, 8.0}, {22.0, 13.0}
  ]

  @crisium [
    {50.5, 17.5}, {52.5, 22.0}, {56.5, 24.5}, {62.5, 23.0},
    {66.0, 18.5}, {66.5, 13.0}, {63.0, 9.5}, {57.0, 9.0},
    {52.0, 11.0}, {50.0, 14.0}, {50.5, 17.5}
  ]

  @fecunditatis [
    {42.0, 1.0}, {44.0, -3.0}, {46.5, -7.5}, {50.0, -11.5},
    {56.0, -12.5}, {58.0, -8.5}, {58.0, -3.5}, {54.5, 0.0},
    {48.0, 2.0}, {42.0, 1.0}
  ]

  @nectaris [
    {31.0, -9.0}, {33.5, -12.0}, {37.5, -14.0}, {40.0, -17.0},
    {39.5, -21.0}, {35.0, -22.5}, {30.0, -20.5}, {28.5, -15.5},
    {30.0, -11.0}, {31.0, -9.0}
  ]

  @nubium [
    {-22.0, -14.0}, {-18.0, -17.5}, {-12.0, -19.0}, {-6.5, -20.0},
    {-4.0, -23.5}, {-8.0, -26.0}, {-14.0, -26.5}, {-20.0, -25.0},
    {-24.5, -21.5}, {-24.0, -17.0}, {-22.0, -14.0}
  ]

  @humorum [
    {-34.0, -19.0}, {-32.0, -22.5}, {-34.0, -27.0}, {-39.5, -29.0},
    {-44.0, -26.5}, {-44.5, -22.0}, {-41.0, -18.5}, {-36.5, -17.5},
    {-34.0, -19.0}
  ]

  @frigoris [
    # Long east-west band north of Imbrium
    {-55.0, 54.0}, {-40.0, 58.0}, {-20.0, 61.0}, {0.0, 60.0},
    {18.0, 57.5}, {35.0, 56.5}, {40.0, 54.0}, {32.0, 51.5},
    {15.0, 52.5}, {0.0, 54.0}, {-25.0, 52.0}, {-45.0, 50.0},
    {-55.0, 54.0}
  ]

  @procellarum [
    # The largest mare — a sprawling "ocean" on the western hemisphere
    {-85.0, 45.0}, {-70.0, 48.5}, {-55.0, 42.0}, {-45.0, 37.0},
    {-40.0, 28.0}, {-38.0, 17.0}, {-42.0, 4.0}, {-48.0, -5.0},
    {-55.0, -15.0}, {-64.0, -22.0}, {-75.0, -22.0}, {-80.0, -12.0},
    {-82.0, 0.0}, {-83.0, 14.0}, {-83.0, 30.0}, {-85.0, 45.0}
  ]

  @cognitum [
    {-25.0, -7.0}, {-22.0, -9.0}, {-19.5, -11.5}, {-20.5, -14.0},
    {-24.5, -13.5}, {-27.0, -10.5}, {-25.0, -7.0}
  ]

  @vaporum [
    {0.5, 16.5}, {4.5, 15.5}, {7.5, 12.5}, {5.5, 9.0},
    {1.0, 9.5}, {-1.5, 12.5}, {0.5, 16.5}
  ]

  @smythii [
    # Mare Smythii — on the eastern limb, ~2°S, 86°E
    {82.5, 4.0}, {86.0, 5.5}, {90.0, 2.0}, {91.5, -3.0},
    {88.0, -6.5}, {83.0, -4.5}, {81.5, 0.0}, {82.5, 4.0}
  ]

  @mare_features [
    {"Mare Imbrium", @imbrium},
    {"Mare Serenitatis", @serenitatis},
    {"Mare Tranquillitatis", @tranquillitatis},
    {"Mare Crisium", @crisium},
    {"Mare Fecunditatis", @fecunditatis},
    {"Mare Nectaris", @nectaris},
    {"Mare Nubium", @nubium},
    {"Mare Humorum", @humorum},
    {"Mare Frigoris", @frigoris},
    {"Oceanus Procellarum", @procellarum},
    {"Mare Cognitum", @cognitum},
    {"Mare Vaporum", @vaporum},
    {"Mare Smythii", @smythii}
  ]

  @doc "Returns the list of lunar mare features."
  @spec maria() :: [Bland.Basemaps.feature()]
  def maria do
    Enum.map(@mare_features, fn {name, pts} ->
      %{name: name, points: normalize(pts), closed?: true}
    end)
  end

  defp normalize(points) do
    pts = Enum.map(points, fn {lon, lat} -> {lon * 1.0, lat * 1.0} end)

    case {List.first(pts), List.last(pts)} do
      {first, last} when first == last -> pts
      _ -> pts ++ [List.first(pts)]
    end
  end
end
