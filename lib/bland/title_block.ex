defmodule Bland.TitleBlock do
  @moduledoc """
  Engineering-drawing title block.

  A title block is the nested rectangle grid you find in the bottom-right
  corner of a drafting sheet. It records provenance: project, title,
  author, date, scale, sheet number, revision. BLAND renders it as plain
  SVG so it prints cleanly on paper.

  Attach one to a figure with `Bland.title_block/2`:

      Bland.figure()
      |> Bland.line(xs, ys)
      |> Bland.title_block(
        project: "Project ORION",
        title: "Drag coefficient vs Mach",
        drawn_by: "J. Doe",
        checked_by: "R. Koss",
        date: "1974-03-21",
        scale: "1:1",
        sheet: "3 of 9",
        rev: "B"
      )
  """

  @type t :: %__MODULE__{
          project: String.t() | nil,
          title: String.t() | nil,
          drawn_by: String.t() | nil,
          checked_by: String.t() | nil,
          date: String.t() | nil,
          scale: String.t() | nil,
          sheet: String.t() | nil,
          rev: String.t() | nil,
          drawing_no: String.t() | nil,
          position: :bottom_right | :bottom_left,
          width: number(),
          height: number()
        }

  defstruct project: nil,
            title: nil,
            drawn_by: nil,
            checked_by: nil,
            date: nil,
            scale: nil,
            sheet: nil,
            rev: nil,
            drawing_no: nil,
            position: :bottom_right,
            width: 380,
            height: 90

  @doc "Builds a title block struct from a keyword list."
  @spec new(keyword()) :: t()
  def new(opts \\ []), do: struct(__MODULE__, opts)
end
