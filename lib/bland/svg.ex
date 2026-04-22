defmodule Bland.Svg do
  @moduledoc """
  Low-level SVG element builders.

  Each builder returns an iodata fragment. The renderer composes fragments
  and only flattens to a binary at the very end, which keeps large plots
  cheap to construct.

  The helpers in this module do not know about data or scales — they speak
  only in pixel coordinates. Use `Bland.Scale.project/2` first, then pass the
  result in here.
  """

  @type attrs :: Enumerable.t()
  @type iodata_frag :: iodata()

  @doc """
  Wraps a `%Bland.Figure{}`-sized viewBox around a body of SVG fragments.
  """
  @spec document(number(), number(), iodata()) :: iodata()
  def document(width, height, body) do
    [
      ~s|<?xml version="1.0" encoding="UTF-8"?>\n|,
      ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 |,
      num(width),
      " ",
      num(height),
      ~s|" width="|,
      num(width),
      ~s|" height="|,
      num(height),
      ~s|" shape-rendering="geometricPrecision" font-family="Times, 'Liberation Serif', serif">|,
      body,
      "</svg>"
    ]
  end

  @doc "Group element with attributes."
  @spec g(attrs(), iodata()) :: iodata()
  def g(attrs, body), do: ["<g", attrs(attrs), ">", body, "</g>"]

  @doc "Defs block — for `<pattern>`, `<marker>`, `<clipPath>` etc."
  @spec defs(iodata()) :: iodata()
  def defs(body), do: ["<defs>", body, "</defs>"]

  @doc "Rectangle."
  @spec rect(number(), number(), number(), number(), attrs()) :: iodata()
  def rect(x, y, w, h, attrs \\ []) do
    [
      ~s|<rect x="|, num(x),
      ~s|" y="|, num(y),
      ~s|" width="|, num(w),
      ~s|" height="|, num(h), ~s|"|,
      attrs(attrs),
      "/>"
    ]
  end

  @doc "Line from `(x1,y1)` to `(x2,y2)`."
  @spec line(number(), number(), number(), number(), attrs()) :: iodata()
  def line(x1, y1, x2, y2, attrs \\ []) do
    [
      ~s|<line x1="|, num(x1),
      ~s|" y1="|, num(y1),
      ~s|" x2="|, num(x2),
      ~s|" y2="|, num(y2), ~s|"|,
      attrs(attrs),
      "/>"
    ]
  end

  @doc "Circle with center and radius."
  @spec circle(number(), number(), number(), attrs()) :: iodata()
  def circle(cx, cy, r, attrs \\ []) do
    [
      ~s|<circle cx="|, num(cx),
      ~s|" cy="|, num(cy),
      ~s|" r="|, num(r), ~s|"|,
      attrs(attrs),
      "/>"
    ]
  end

  @doc "Polyline from a list of `{x, y}` tuples."
  @spec polyline([{number(), number()}], attrs()) :: iodata()
  def polyline(points, attrs \\ []) do
    [
      ~s|<polyline points="|,
      points_str(points),
      ~s|"|,
      attrs([{:fill, "none"} | Enum.to_list(attrs)]),
      "/>"
    ]
  end

  @doc "Polygon from a list of `{x, y}` tuples."
  @spec polygon([{number(), number()}], attrs()) :: iodata()
  def polygon(points, attrs \\ []) do
    [
      ~s|<polygon points="|,
      points_str(points),
      ~s|"|,
      attrs(attrs),
      "/>"
    ]
  end

  @doc "General path from an SVG `d` string."
  @spec path(iodata(), attrs()) :: iodata()
  def path(d, attrs \\ []) do
    [~s|<path d="|, d, ~s|"|, attrs(attrs), "/>"]
  end

  @doc """
  Text element. `content` is written literally — escape it with `escape/1`
  if it may contain user input.
  """
  @spec text(number(), number(), iodata(), attrs()) :: iodata()
  def text(x, y, content, attrs \\ []) do
    [
      ~s|<text x="|, num(x),
      ~s|" y="|, num(y), ~s|"|,
      attrs(attrs),
      ">",
      content,
      "</text>"
    ]
  end

  @doc """
  XML-escapes a string for safe insertion into element text or attribute
  values.
  """
  @spec escape(String.t()) :: String.t()
  def escape(s) when is_binary(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  @doc """
  Renders a keyword list or map of attributes into an SVG attribute string
  suffix (`" k1=\\"v1\\" k2=\\"v2\\""`). Underscores in keys are converted
  to hyphens so `stroke_width: 1` becomes `stroke-width="1"`.
  """
  @spec attrs(attrs()) :: iodata()
  def attrs(attrs) do
    attrs
    |> Enum.map(fn
      {_k, nil} -> []
      {k, v} -> [" ", attr_key(k), ~s|="|, attr_val(v), ~s|"|]
    end)
  end

  @doc "Formats a numeric value with up to 3 decimals, trimming trailing zeros."
  @spec num(number()) :: String.t()
  def num(v) when is_integer(v), do: Integer.to_string(v)

  def num(v) when is_float(v) do
    rounded = Float.round(v, 3)

    if rounded == trunc(rounded),
      do: Integer.to_string(trunc(rounded)),
      else: :erlang.float_to_binary(rounded, decimals: 3) |> trim_trailing_zeros()
  end

  defp trim_trailing_zeros(s) do
    s
    |> String.replace(~r/(\.\d*?)0+$/, "\\1")
    |> String.replace(~r/\.$/, "")
  end

  defp points_str(points) do
    points
    |> Enum.map(fn {x, y} -> [num(x), ",", num(y)] end)
    |> Enum.intersperse(" ")
  end

  defp attr_key(k) when is_atom(k),
    do: k |> Atom.to_string() |> String.replace("_", "-")

  defp attr_key(k) when is_binary(k), do: k

  defp attr_val(v) when is_integer(v) or is_float(v), do: num(v)
  defp attr_val(v) when is_binary(v), do: escape(v)
  defp attr_val(v) when is_atom(v), do: Atom.to_string(v)
  defp attr_val(v) when is_list(v), do: v
end
