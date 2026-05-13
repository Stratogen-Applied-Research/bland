defmodule Bland.Kino do
  @moduledoc """
  Minimal Livebook integration for live-updating plots.

  Wraps `Kino.Frame` so realtime data streams can re-render a figure
  in place inside a notebook without re-running the cell.

  ## Pattern

      # In a Livebook cell — bind the frame once at the top, return it
      frame = Bland.Kino.frame()

  Then push updates from any other cell, GenServer tick, etc.:

      # Build a figure normally each time
      fig =
        Bland.figure(title: "Live")
        |> Bland.line(xs, ys)

      # Replace what the frame shows
      Bland.Kino.push(frame, fig)

  A pushed figure renders immediately. There's no GenServer here — the
  user owns the data buffer and decides when to render. For periodic
  refresh, wrap the push in a `Stream.interval/1` or a `Task`.

  ## Throttling

  If you push from a tight loop, throttle the push side — Livebook can
  comfortably handle a few updates per second but not hundreds. The
  simplest approach is a sleep between pushes; for high-rate data,
  accumulate a buffer and push at a fixed cadence.

  ## Outside Livebook

  This module gracefully no-ops if `:kino` isn't loaded. Calling
  `frame/0` outside Livebook raises a useful message.
  """

  @doc """
  Returns a new `Kino.Frame` instance. The frame is initially empty;
  call `push/2` to put a figure in it.

  Raises if `:kino` is not available (i.e. outside a Livebook).
  """
  def frame do
    ensure_kino!()
    apply(Kino.Frame, :new, [])
  end

  @doc """
  Renders `figure_or_svg` and pushes it into `frame`, replacing
  whatever the frame was previously displaying.

  Accepts:

    * `%Bland.Figure{}` — rendered via `Bland.to_svg/1`
    * `binary` — used as-is (lets users compose SVGs externally, e.g.
      via `Bland.grid/2`)
  """
  def push(frame, figure_or_svg)

  def push(frame, %Bland.Figure{} = fig), do: push(frame, Bland.to_svg(fig))

  def push(frame, svg) when is_binary(svg) do
    ensure_kino!()
    image = apply(Kino.Image, :new, [svg, "image/svg+xml"])
    apply(Kino.Frame, :render, [frame, image])
    :ok
  end

  defp ensure_kino! do
    unless Code.ensure_loaded?(Kino.Frame) do
      raise """
      Bland.Kino requires :kino. In a Livebook cell, add:

          Mix.install([{:bland, "~> 0.3"}, {:kino, "~> 0.14"}])
      """
    end

    :ok
  end
end
