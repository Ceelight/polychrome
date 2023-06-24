defmodule Octopus.Transitions do
  alias Octopus.Canvas

  @moduledoc """
  Implements transitions between two canvases.

  Returns a stream of canvases.
  """

  def flipdot(%Canvas{} = canvas1, %Canvas{} = canvas2) do
    coordinates = for y <- 0..(canvas2.height - 1), x <- 0..(canvas2.width - 1), do: {x, y}

    Stream.transform(
      coordinates,
      canvas1,
      fn coordinate, canvas ->
        pixel = Canvas.get_pixel(canvas2, coordinate)
        canvas = Canvas.put_pixel(canvas, coordinate, pixel)
        {[canvas], canvas}
      end
    )
  end

  @doc """
  Canvas2 pushes canvas1 out to one side. It uses easings for a smooth transtion.
  Returns a stream of canvases that are intended to be played at constant frame rate.

  ## Options
  * `:direction` - `:left`, `:right`, `:top`, or `:bottom` [default: `:left`]
  * `:separation` - number of separation pixels between the two canvases [default: 3]
  * `:step_count` - number of steps to use for the transition [default: 50]

  """

  def push(%Canvas{palette: palette} = canvas1, %Canvas{palette: palette} = canvas2, opts \\ []) do
    direction = Keyword.get(opts, :direction, :left)
    separation = Keyword.get(opts, :separation, 3)
    step_count = Keyword.get(opts, :step_count, 50)

    joined =
      case direction do
        :left ->
          canvas1
          |> Canvas.join(Canvas.new(separation, canvas1.height, palette), direction: :horizontal)
          |> Canvas.join(canvas2, direction: :horizontal)

        :right ->
          canvas2
          |> Canvas.join(Canvas.new(separation, canvas2.height, palette), direction: :horizontal)
          |> Canvas.join(canvas1, direction: :horizontal)

        :top ->
          canvas1
          |> Canvas.join(Canvas.new(canvas1.width, separation, palette), direction: :vertical)
          |> Canvas.join(canvas2, direction: :vertical)

        :bottom ->
          canvas2
          |> Canvas.join(Canvas.new(canvas2.width, separation, palette), direction: :vertical)
          |> Canvas.join(canvas1, direction: :vertical)
      end

    cuts =
      case direction do
        :left ->
          0..(canvas1.width + separation)
          |> Enum.map(fn x -> {{x, 0}, {x + canvas1.width - 1, joined.height}} end)

        :right ->
          (canvas1.width + separation)..0
          |> Enum.map(fn x -> {{x, 0}, {x + canvas1.width - 1, joined.height}} end)

        :top ->
          0..(canvas1.height + separation)
          |> Enum.map(fn y -> {{0, y}, {joined.width, y + canvas1.height}} end)

        :bottom ->
          (canvas1.height + separation)..0
          |> Enum.map(fn y -> {{0, y}, {joined.width, y + canvas1.height}} end)
      end

    0..(step_count - 1)
    |> Stream.map(fn step -> Easing.quadratic_in_out(step / step_count) end)
    |> Stream.map(fn ratio ->
      Enum.at(cuts, round(ratio * (length(cuts) - 1)))
    end)
    |> Stream.map(fn {cut_start, cut_end} ->
      Canvas.cut(joined, cut_start, cut_end)
    end)
  end
end
