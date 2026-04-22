defmodule Bland.Scale do
  @moduledoc """
  Coordinate scaling between *data space* and *canvas space*.

  A `Scale` maps a closed interval in the data domain onto a pixel range on the
  output canvas. `linear/2` and `log/2` are the two supported scale families.

  The plotting pipeline holds one scale per axis on each `Bland.Figure`, and
  series use `project/2` to translate data tuples into pixel coordinates.

      iex> s = Bland.Scale.linear({0.0, 10.0}, {40.0, 440.0})
      iex> Bland.Scale.project(s, 5.0)
      240.0
  """

  @type domain :: {number(), number()}
  @type range :: {number(), number()}
  @type t :: %__MODULE__{
          domain: domain(),
          range: range(),
          type: :linear | :log,
          base: number()
        }

  defstruct domain: {0.0, 1.0}, range: {0.0, 1.0}, type: :linear, base: 10

  @doc """
  Builds a linear scale mapping `domain` to `range`.
  """
  @spec linear(domain(), range()) :: t()
  def linear({d0, d1}, {r0, r1}) when d0 != d1,
    do: %__MODULE__{domain: {d0 * 1.0, d1 * 1.0}, range: {r0 * 1.0, r1 * 1.0}, type: :linear}

  @doc """
  Builds a log-base scale. `base` defaults to 10. Both domain endpoints must be > 0.
  """
  @spec log(domain(), range(), number()) :: t()
  def log({d0, d1}, {r0, r1}, base \\ 10) when d0 > 0 and d1 > 0 and d0 != d1,
    do: %__MODULE__{
      domain: {d0 * 1.0, d1 * 1.0},
      range: {r0 * 1.0, r1 * 1.0},
      type: :log,
      base: base
    }

  @doc """
  Projects a data-space value into canvas-space.
  """
  @spec project(t(), number()) :: float()
  def project(%__MODULE__{type: :linear, domain: {d0, d1}, range: {r0, r1}}, v) do
    r0 + (v - d0) / (d1 - d0) * (r1 - r0)
  end

  def project(%__MODULE__{type: :log, domain: {d0, d1}, range: {r0, r1}, base: b}, v) do
    logv = :math.log(v) / :math.log(b)
    logd0 = :math.log(d0) / :math.log(b)
    logd1 = :math.log(d1) / :math.log(b)
    r0 + (logv - logd0) / (logd1 - logd0) * (r1 - r0)
  end

  @doc """
  Inverse of `project/2`. Converts a canvas-space coordinate back to data-space.
  """
  @spec invert(t(), number()) :: float()
  def invert(%__MODULE__{type: :linear, domain: {d0, d1}, range: {r0, r1}}, px) do
    d0 + (px - r0) / (r1 - r0) * (d1 - d0)
  end

  def invert(%__MODULE__{type: :log, domain: {d0, d1}, range: {r0, r1}, base: b}, px) do
    logd0 = :math.log(d0) / :math.log(b)
    logd1 = :math.log(d1) / :math.log(b)
    l = logd0 + (px - r0) / (r1 - r0) * (logd1 - logd0)
    :math.pow(b, l)
  end

  @doc """
  Derives a reasonable data-space domain from a list of numbers by padding
  `padding * span` on each end. Zero-span inputs get `±1` padding so the
  resulting scale never collapses to a point.
  """
  @spec auto_domain([number()], float()) :: domain()
  def auto_domain(values, padding \\ 0.05)
  def auto_domain([], _padding), do: {0.0, 1.0}

  def auto_domain(values, padding) when is_list(values) do
    {lo, hi} = Enum.min_max(values)

    cond do
      lo == hi and lo == 0 -> {-1.0, 1.0}
      lo == hi -> {lo - abs(lo) * 0.1, hi + abs(hi) * 0.1}
      true -> pad = (hi - lo) * padding
              {lo - pad, hi + pad}
    end
  end
end
