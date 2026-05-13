defmodule Bland.Phoenix.Component do
  @moduledoc """
  Phoenix LiveView component — embeds a `%Bland.Figure{}` as inline
  SVG in a HEEx template.

  Pair this with LiveView's normal change tracking and you get a
  realtime plotting dashboard: assign a new figure to the socket,
  LiveView pushes the SVG diff, the browser swaps it. No JavaScript
  needed, no canvas, no separate render endpoint.

  ## Setup

  Add `phoenix_live_view` to your app's deps (it's optional in BLAND):

      def deps do
        [
          {:bland, "~> 0.4"},
          {:phoenix_live_view, "~> 1.0"}
        ]
      end

  ## Usage

      defmodule MyAppWeb.DashboardLive do
        use MyAppWeb, :live_view
        import Bland.Phoenix.Component

        def mount(_params, _session, socket) do
          if connected?(socket), do: :timer.send_interval(1_000, :tick)
          {:ok, assign(socket, history: [], figure: empty_figure())}
        end

        def handle_info(:tick, socket) do
          point = read_sensor()
          history = [point | socket.assigns.history] |> Enum.take(120)
          fig = build_figure(history)
          {:noreply, assign(socket, history: history, figure: fig)}
        end

        def render(assigns) do
          ~H\"\"\"
          <div class="dashboard">
            <.bland_figure figure={@figure} class="plot" />
          </div>
          \"\"\"
        end

        defp build_figure(history) do
          {xs, ys} = Enum.unzip(history)

          Bland.figure(size: {800, 400}, title: "Sensor")
          |> Bland.axes(xlabel: "t [s]", ylabel: "value")
          |> Bland.line(xs, ys)
        end
      end

  ## Performance

  Each update re-renders the figure to SVG (5–100 KB typical) and sends
  it as part of LiveView's diff. That's fine for human-readable
  cadences — 1 Hz is comfortable, 10 Hz is the practical ceiling for
  most dashboards. For higher rates, push less often and batch points
  on the server side.

  ## Component reference

  Pass either `:figure` (a `%Bland.Figure{}`) or `:svg` (a pre-rendered
  SVG binary, e.g. the output of `Bland.grid/2`). `:figure` wins if both
  are provided.
  """

  if Code.ensure_loaded?(Phoenix.Component) do
    use Phoenix.Component

    @doc """
    Renders a BLAND figure as inline SVG inside a wrapping `<div>`.

    ## Attributes

      * `:figure` — `%Bland.Figure{}`; rendered with `Bland.to_svg/1`
      * `:svg`    — pre-rendered SVG binary, used when `:figure` is `nil`
      * `:class`  — CSS class on the wrapping `<div>`
      * `:style`  — inline style on the wrapping `<div>`
      * `:id`     — DOM id

    LiveView change tracking handles diff/morph automatically. Each
    distinct figure value pushes a fresh SVG to the client; identical
    figures don't push anything.
    """
    attr :figure, :any, default: nil
    attr :svg, :string, default: nil
    attr :class, :string, default: nil
    attr :style, :string, default: nil
    attr :id, :string, default: nil

    def bland_figure(assigns) do
      svg = render_svg(assigns)
      assigns = Phoenix.Component.assign(assigns, :__bland_svg__, svg)

      ~H"""
      <div id={@id} class={@class} style={@style}>
        {Phoenix.HTML.raw(@__bland_svg__)}
      </div>
      """
    end

    defp render_svg(%{figure: %Bland.Figure{} = fig}),
      do: fig |> Bland.to_svg() |> strip_xml_prolog()

    defp render_svg(%{svg: svg}) when is_binary(svg),
      do: strip_xml_prolog(svg)

    defp render_svg(_), do: ""

    # The XML prolog is invalid inside HTML — strip it before embedding.
    defp strip_xml_prolog(svg) do
      String.replace(svg, ~r/^\s*<\?xml[^>]*\?>\s*/, "")
    end
  else
    @doc false
    def bland_figure(_assigns) do
      raise """
      Bland.Phoenix.Component requires Phoenix.LiveView.

      Add to your mix.exs:

          {:phoenix_live_view, "~> 1.0"}
      """
    end
  end
end
