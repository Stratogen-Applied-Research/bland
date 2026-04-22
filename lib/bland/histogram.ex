defmodule Bland.Histogram do
  @moduledoc """
  Binning helpers for histograms.

  Given a list of numeric observations, `bin/2` returns the computed
  `{edges, values, density?}` triple used by `%Bland.Series.Histogram{}`.

  `Bland.histogram/3` calls this for you at series-construction time; you
  only need `bin/2` directly if you want to pre-compute bin counts
  outside of a figure (e.g. to render a table alongside the plot).

  ## Bin-count strategies

    * integer `N`           — exactly N equal-width bins
    * `:sturges`            — `⌈1 + log₂(n)⌉` (default)
    * `:sqrt`               — `⌈√n⌉`
    * `:scott`              — `⌈(max-min) / (3.49·σ·n^(-1/3))⌉`
    * `:freedman_diaconis`  — `⌈(max-min) / (2·IQR·n^(-1/3))⌉`

  Pass explicit `bin_edges: [...]` to skip strategy selection entirely.

      iex> {edges, counts, _} = Bland.Histogram.bin([1, 2, 2, 3, 3, 3], bins: 3)
      iex> {length(edges), counts}
      {4, [1, 2, 3]}
  """

  @type strategy :: pos_integer() | :sturges | :sqrt | :scott | :freedman_diaconis
  @type opts :: [
          bins: strategy(),
          bin_edges: [number()],
          density: boolean()
        ]

  @doc """
  Bins `observations`.

  Returns `{bin_edges, values, density?}` where:

    * `bin_edges` is a list of length `n_bins + 1`
    * `values` is a list of length `n_bins` — either integer counts or
      float densities (counts normalized so `Σ values · bin_width = 1`)
    * `density?` is `true` when `density: true` was passed

  Options:

    * `:bins`      — bin-count strategy (default `:sturges`)
    * `:bin_edges` — explicit edge list; overrides `:bins`
    * `:density`   — normalize to densities (default `false`)

  Observations that fall outside `[bin_edges |> hd, bin_edges |> List.last]`
  are silently dropped.
  """
  @spec bin([number()], opts()) :: {[float()], [number()], boolean()}
  def bin([], _opts), do: {[0.0, 1.0], [0], false}

  def bin(observations, opts) when is_list(observations) do
    density? = Keyword.get(opts, :density, false)
    edges = resolve_edges(observations, opts)
    counts = count_in(observations, edges)

    values =
      if density? do
        total = Enum.sum(counts)
        widths = bin_widths(edges)

        Enum.zip(counts, widths)
        |> Enum.map(fn {c, w} ->
          cond do
            total == 0 -> 0.0
            w == 0 -> 0.0
            true -> c / (total * w)
          end
        end)
      else
        counts
      end

    {edges, values, density?}
  end

  @doc "Edges computed for `observations` under the given strategy."
  @spec edges([number()], opts()) :: [float()]
  def edges(observations, opts), do: resolve_edges(observations, opts)

  # --- edge computation -----------------------------------------------------

  defp resolve_edges(observations, opts) do
    case Keyword.get(opts, :bin_edges) do
      nil ->
        strategy = Keyword.get(opts, :bins, :sturges)
        auto_edges(observations, strategy)

      edges when is_list(edges) and length(edges) >= 2 ->
        Enum.map(edges, &(&1 * 1.0))
    end
  end

  defp auto_edges(observations, strategy) do
    {lo, hi} = Enum.min_max(observations)
    n = length(observations)

    {lo, hi} =
      cond do
        lo == hi and lo == 0 -> {-0.5, 0.5}
        lo == hi -> {lo - abs(lo) * 0.1, hi + abs(hi) * 0.1}
        true -> {lo, hi}
      end

    k = resolve_bin_count(observations, strategy, n, lo, hi) |> max(1)
    step = (hi - lo) / k

    Enum.map(0..k, fn i -> lo + i * step end)
  end

  defp resolve_bin_count(_obs, k, _n, _lo, _hi) when is_integer(k) and k > 0, do: k
  defp resolve_bin_count(_obs, :sturges, n, _lo, _hi) when n > 0,
    do: ceil(1 + :math.log2(n))

  defp resolve_bin_count(_obs, :sqrt, n, _lo, _hi) when n > 0,
    do: ceil(:math.sqrt(n))

  defp resolve_bin_count(obs, :scott, n, lo, hi) when n > 1 do
    sigma = stddev(obs)

    cond do
      sigma <= 0.0 -> ceil(:math.sqrt(n))
      true ->
        h = 3.49 * sigma * :math.pow(n, -1 / 3)
        if h <= 0, do: ceil(:math.sqrt(n)), else: ceil((hi - lo) / h)
    end
  end

  defp resolve_bin_count(obs, :freedman_diaconis, n, lo, hi) when n > 1 do
    iqr = iqr(obs)

    cond do
      iqr <= 0.0 -> ceil(:math.sqrt(n))
      true ->
        h = 2 * iqr * :math.pow(n, -1 / 3)
        if h <= 0, do: ceil(:math.sqrt(n)), else: ceil((hi - lo) / h)
    end
  end

  defp resolve_bin_count(_obs, _strategy, n, _lo, _hi), do: max(1, ceil(:math.sqrt(n)))

  # --- counting -------------------------------------------------------------

  defp count_in(observations, edges) do
    pairs = Enum.chunk_every(edges, 2, 1, :discard)
    n_bins = length(pairs)
    last = n_bins - 1

    freqs =
      Enum.frequencies_by(observations, fn v ->
        find_bin(v, pairs, last)
      end)

    for i <- 0..max(last, 0), do: Map.get(freqs, i, 0)
  end

  defp find_bin(v, pairs, last) do
    pairs
    |> Enum.with_index()
    |> Enum.find_value(fn {[lo, hi], i} ->
      cond do
        i == last and v >= lo and v <= hi -> i
        v >= lo and v < hi -> i
        true -> nil
      end
    end)
  end

  defp bin_widths(edges) do
    edges
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [lo, hi] -> hi - lo end)
  end

  # --- simple stats ---------------------------------------------------------

  defp stddev(values) do
    n = length(values)
    mean = Enum.sum(values) / n
    variance = Enum.reduce(values, 0.0, fn v, acc -> acc + (v - mean) ** 2 end) / n
    :math.sqrt(variance)
  end

  defp iqr(values) do
    sorted = Enum.sort(values)
    q1 = percentile(sorted, 0.25)
    q3 = percentile(sorted, 0.75)
    q3 - q1
  end

  defp percentile(sorted, p) do
    n = length(sorted)
    rank = p * (n - 1)
    lo = trunc(rank)
    hi = min(lo + 1, n - 1)
    frac = rank - lo
    a = Enum.at(sorted, lo)
    b = Enum.at(sorted, hi)
    a + frac * (b - a)
  end
end
