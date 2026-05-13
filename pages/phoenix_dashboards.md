# Phoenix LiveView Dashboards

For long-running realtime displays — process monitors, lab
instruments, market tickers, telemetry boards — BLAND ships a
function component that renders a `%Bland.Figure{}` as inline SVG.
Combined with LiveView's normal change tracking, a single
`assign(socket, :figure, fig)` push updates the chart in the browser
with no JavaScript on your end.

## Setup

Add `phoenix_live_view` to your app's deps alongside `bland`:

```elixir
def deps do
  [
    {:bland, "~> 0.4"},
    {:phoenix_live_view, "~> 1.0"}
  ]
end
```

`phoenix_live_view` is declared `optional: true` in BLAND, so it's only
pulled in when you explicitly add it.

## Minimal LiveView

```elixir
defmodule MyAppWeb.SensorLive do
  use MyAppWeb, :live_view
  import Bland.Phoenix.Component

  @history_size 120

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(500, :tick)

    {:ok,
     socket
     |> assign(history: [])
     |> assign_figure()}
  end

  def handle_info(:tick, socket) do
    point = {System.system_time(:second), read_sensor()}
    history = [point | socket.assigns.history] |> Enum.take(@history_size)

    {:noreply,
     socket
     |> assign(history: history)
     |> assign_figure()}
  end

  defp assign_figure(socket) do
    {ts, ys} = Enum.unzip(socket.assigns.history)
    xs = Enum.map(ts, &(&1 - List.last(ts, 0)))

    fig =
      Bland.figure(size: {900, 360}, title: "Live sensor")
      |> Bland.axes(xlabel: "t [s]", ylabel: "reading")
      |> Bland.line(Enum.reverse(xs), Enum.reverse(ys), label: "ch.1")
      |> Bland.legend(position: :top_right)

    assign(socket, :figure, fig)
  end

  def render(assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-6 p-6">
      <.bland_figure figure={@figure} class="bg-white rounded-lg shadow" />
    </div>
    """
  end
end
```

Every 500 ms the LiveView pulls a fresh reading, builds a new
`%Bland.Figure{}`, and assigns it. LiveView sees the figure changed,
re-renders the template, and pushes the new SVG to the browser. The
browser does a morph diff and swaps it in place.

## Component attributes

```heex
<.bland_figure figure={@figure} />
<.bland_figure svg={@composite_svg} />
<.bland_figure figure={@figure} class="plot" style="max-width: 100%" id="ch1" />
```

  * `:figure` — a `%Bland.Figure{}`. Rendered via `Bland.to_svg/1`.
  * `:svg` — pre-rendered SVG binary. Use this for `Bland.grid/2`
    output, which returns SVG directly.
  * `:class`, `:style`, `:id` — applied to the wrapping `<div>`.

`:figure` wins if both are provided. The XML prolog is stripped
automatically so the SVG embeds cleanly into the HTML response.

## Multi-panel dashboards

Compose subplots into one SVG with `Bland.grid/2`, then pass the
result as `:svg`:

```elixir
def render(assigns) do
  ~H"""
  <.bland_figure svg={@dashboard_svg} class="dashboard-grid" />
  """
end

defp build_dashboard(state) do
  Bland.grid(
    [
      build_throughput(state),
      build_latency(state),
      build_errors(state),
      build_queue_depth(state)
    ],
    columns: 2,
    cell_width: 480,
    cell_height: 280
  )
end
```

The composite is a single SVG, so updates push as one diff regardless
of how many panels you've packed in.

## Patterns

### Bounded history with a circular buffer

For continuous streams, keep the in-memory history bounded so the
figure stays responsive:

```elixir
@history_size 500
history = [new_point | socket.assigns.history] |> Enum.take(@history_size)
```

For high-rate data, decimate on the way in (e.g. only keep every Nth
sample, or pre-aggregate windowed means).

### Multiple subscribers, one source

If multiple LiveViews want the same data, put a GenServer in front:

```elixir
defmodule MyApp.SensorBus do
  use GenServer

  def subscribe, do: Phoenix.PubSub.subscribe(MyApp.PubSub, "sensor")

  # ... GenServer that reads the sensor and broadcasts
  # Phoenix.PubSub.broadcast(MyApp.PubSub, "sensor", {:tick, point})
end
```

Each LiveView calls `MyApp.SensorBus.subscribe()` in `mount/3` and
handles `{:tick, point}` in `handle_info/2`. One sensor, many viewers.

### PubSub-driven updates

```elixir
def mount(_params, _session, socket) do
  if connected?(socket), do: Phoenix.PubSub.subscribe(MyApp.PubSub, "metrics")
  {:ok, assign(socket, history: [])}
end

def handle_info({:metric, point}, socket) do
  history = [point | socket.assigns.history] |> Enum.take(120)
  {:noreply, assign(socket, history: history, figure: build_figure(history))}
end
```

## Performance notes

Each update re-renders the figure to SVG (typically 5–100 KB) and
ships it as part of the LiveView diff. That's comfortable up to
~10 Hz across a normal network. For higher rates:

  * **Decimate on input.** A 1 kHz sensor with 100 visible bins on the
    chart only needs 100 points; aggregate the rest on the server.
  * **Throttle the assign.** Buffer points and call `assign_figure`
    on a fixed timer rather than on each datum.
  * **Lower-res figures.** A 400×200 chart sends much less SVG than a
    1200×800 one. Adjust `size:` and let CSS scale.

## Inline SVG vs. iframe

BLAND uses *inline SVG* (raw `<svg>` injected into the page), not an
`<img src="…"/>` reference. That means:

  * No extra HTTP request per update.
  * The SVG participates in CSS — you can style the wrapping `<div>`
    with `max-width`, set a background, animate transitions.
  * LiveView's morph diff swaps the SVG cleanly without flicker.

The price is a slightly larger DOM. For a few panels at modest size,
that's negligible.
