defmodule Bland.Stats do
  @moduledoc """
  Small stats helpers used by the box-plot, Q-Q, and histogram
  routines. Intentionally narrow — this is not a general stats
  library.
  """

  @doc """
  Linearly-interpolated quantile (type-7, R's default). `p` is in
  `[0, 1]`.

      iex> Bland.Stats.quantile([1, 2, 3, 4, 5], 0.5)
      3.0
  """
  @spec quantile([number()], number()) :: float()
  def quantile([], _p), do: 0.0
  def quantile([x], _p), do: x * 1.0

  def quantile(values, p) when is_list(values) do
    sorted = Enum.sort(values)
    n = length(sorted)
    rank = p * (n - 1)
    lo = trunc(rank)
    hi = min(lo + 1, n - 1)
    frac = rank - lo
    a = Enum.at(sorted, lo)
    b = Enum.at(sorted, hi)
    a + frac * (b - a)
  end

  @doc """
  Computes a box-plot summary — quartiles plus Tukey fences for whisker
  endpoints. Outliers are observations beyond `1.5·IQR` (default).

  Returns `%{min, q1, median, q3, max, outliers}` where `min/max` are
  the whisker endpoints (*not* the raw extrema — those are captured in
  `:outliers`).

      iex> s = Bland.Stats.boxplot_stats([1, 2, 3, 4, 5, 6, 7, 100])
      iex> {s.median, length(s.outliers)}
      {4.5, 1}
  """
  @spec boxplot_stats([number()], number()) :: map()
  def boxplot_stats(values, whisker_iqr \\ 1.5) when is_list(values) do
    sorted = Enum.sort(values)
    q1 = quantile(sorted, 0.25)
    med = quantile(sorted, 0.5)
    q3 = quantile(sorted, 0.75)
    iqr = q3 - q1

    lower_fence = q1 - whisker_iqr * iqr
    upper_fence = q3 + whisker_iqr * iqr

    inliers = Enum.filter(sorted, &(&1 >= lower_fence and &1 <= upper_fence))

    min_in =
      case inliers do
        [] -> q1
        _ -> Enum.min(inliers)
      end

    max_in =
      case inliers do
        [] -> q3
        _ -> Enum.max(inliers)
      end

    outliers = Enum.reject(sorted, &(&1 >= lower_fence and &1 <= upper_fence))

    %{min: min_in, q1: q1, median: med, q3: q3, max: max_in, outliers: outliers}
  end

  @doc """
  Inverse standard-normal CDF (probit). Uses the Beasley-Springer /
  Moro approximation — accurate to about 1e-9 across the usual range.

      iex> abs(Bland.Stats.normal_quantile(0.5)) < 1.0e-9
      true

      iex> Float.round(Bland.Stats.normal_quantile(0.975), 4)
      1.96
  """
  @spec normal_quantile(number()) :: float()
  def normal_quantile(p) when p > 0 and p < 1 do
    # Beasley-Springer (1977) / Moro (1995) rational approximation.
    a = [-3.969683028665376e+01, 2.209460984245205e+02,
         -2.759285104469687e+02, 1.383577518672690e+02,
         -3.066479806614716e+01, 2.506628277459239e+00]
    b = [-5.447609879822406e+01, 1.615858368580409e+02,
         -1.556989798598866e+02, 6.680131188771972e+01,
         -1.328068155288572e+01]
    c = [-7.784894002430293e-03, -3.223964580411365e-01,
         -2.400758277161838e+00, -2.549732539343734e+00,
          4.374664141464968e+00, 2.938163982698783e+00]
    d = [7.784695709041462e-03, 3.224671290700398e-01,
         2.445134137142996e+00, 3.754408661907416e+00]

    plow = 0.02425
    phigh = 1 - plow

    cond do
      p < plow ->
        q = :math.sqrt(-2 * :math.log(p))

        (((((Enum.at(c, 0) * q + Enum.at(c, 1)) * q + Enum.at(c, 2)) * q + Enum.at(c, 3)) * q +
            Enum.at(c, 4)) * q + Enum.at(c, 5)) /
          ((((Enum.at(d, 0) * q + Enum.at(d, 1)) * q + Enum.at(d, 2)) * q + Enum.at(d, 3)) * q + 1)

      p > phigh ->
        q = :math.sqrt(-2 * :math.log(1 - p))

        -(((((Enum.at(c, 0) * q + Enum.at(c, 1)) * q + Enum.at(c, 2)) * q + Enum.at(c, 3)) * q +
             Enum.at(c, 4)) * q + Enum.at(c, 5)) /
          ((((Enum.at(d, 0) * q + Enum.at(d, 1)) * q + Enum.at(d, 2)) * q + Enum.at(d, 3)) * q + 1)

      true ->
        q = p - 0.5
        r = q * q

        ((((((Enum.at(a, 0) * r + Enum.at(a, 1)) * r + Enum.at(a, 2)) * r + Enum.at(a, 3)) * r +
             Enum.at(a, 4)) * r + Enum.at(a, 5)) * q) /
          (((((Enum.at(b, 0) * r + Enum.at(b, 1)) * r + Enum.at(b, 2)) * r + Enum.at(b, 3)) * r +
              Enum.at(b, 4)) * r + 1)
    end
  end
end
