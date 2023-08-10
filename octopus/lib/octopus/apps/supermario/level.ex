# matrix with level infos (8 * 120 pixel)
# needs to know position of mario (x,y)
#       where x might be fixed (current position, which moves by a ticker)
# might end in gameover
# needs to know bonus points when mario jumps on certain points
defmodule Octopus.Apps.Supermario.Level do
  @moduledoc """
    handles level data
  """
  alias __MODULE__
  # TODO cyclic dependency Game <-> Level
  alias Octopus.Apps.Supermario.{BadGuy, Game, Matrix, PngFile}

  @max_level 4

  @type t :: %__MODULE__{
          # 8 * ~120 .. fixed height, variable width,
          pixels: [],
          level_number: integer(),
          points: integer(),
          bad_guys: [],
          mario_start_y_position: integer()
        }
  defstruct [
    :pixels,
    :level_number,
    :points,
    :bad_guys,
    :mario_start_y_position
  ]

  def new() do
    start_level_number = 1
    %Level{
      pixels: load_pixels(start_level_number),
      level_number: start_level_number,
      bad_guys: init_bad_guys(start_level_number),
      mario_start_y_position: init_mario_start_y_position(start_level_number)
    }
  end

  def restart(%Level{level_number: level_number} = level) do
    %Level{level | bad_guys: init_bad_guys(level_number)}
  end

  def next_level(%Level{level_number: level_number}) do
    level_number = level_number + 1
    %Level{
      level_number: level_number,
      pixels: load_pixels(level_number),
      bad_guys: init_bad_guys(level_number),
      mario_start_y_position: init_mario_start_y_position(level_number)
    }
  end

  def last_level?(%Level{level_number: level_number}), do: level_number >= @max_level

  def max_position(%Level{pixels: pixels}), do: (Enum.at(pixels, 0) |> Enum.count()) - 8

  def can_fall?(_, _, 7), do: false
  def can_fall?(%Level{level_number: level_number}, x_position, y_position) do
    level_number
    |> level_blocks()
    |> Enum.at(y_position + 1)
    |> Enum.at(x_position)
    |> is_nil()
  end

  # can jump when there is no block above
  def can_jump?(_, _, 0), do: false
  def can_jump?(%Level{level_number: level_number}, x_position, y_position) do
    level_number
    |> level_blocks()
    |> Enum.at(y_position - 1)
    |> Enum.at(x_position)
    |> is_nil()
  end

  # check blocks
  def can_move_right?(%Level{level_number: level_number}, x_position, y_position) do
    level_number
    |> level_blocks()
    |> Enum.at(y_position)
    |> Enum.at(x_position + 1)
    |> is_nil()
  end

  def can_move_left?(%Level{level_number: level_number}, x_position, y_position) do
    level_number
    |> level_blocks()
    |> Enum.at(y_position)
    |> Enum.at(x_position - 1)
    |> is_nil()
  end

  def has_bad_guy_on_postion?(%Level{bad_guys: bad_guys}, x_position, y_position) do
    Enum.any?(bad_guys, fn bad_guy -> BadGuy.on_position?(bad_guy, x_position, y_position) end)
  end

  def kill_bad_guy(%Level{} = level, x_position, y_position) do
    %Level{level | bad_guys: Enum.filter(level.bad_guys, fn bad_guy -> not BadGuy.on_position?(bad_guy, x_position, y_position) end)}
  end

  def draw(pixels, %{current_position: current_position},  %Level{bad_guys: bad_guys}) do
    width = pixels |> List.first |> Enum.count()
    Enum.reduce(bad_guys, pixels, fn bad_guy, pixels ->
      BadGuy.draw(pixels, bad_guy, current_position, width)
    end)
  end

  # only for testing, to enable rename to draw and rename or disable empty draw function
  def _draw(pixels, %{current_position: current_position}, %Level{} = level) do
    pixels
    |> Matrix.from_list()
    |> draw_blocks(level, current_position)
    |> Matrix.to_list()
  end

  defp draw_blocks(matrix, %Level{level_number: level_number}, current_position) do
    blocks = level_blocks(level_number)

    {matrix, _} =
      Enum.reduce(blocks, {matrix, 0}, fn row, {matrix, y} ->
        {matrix, _, y} =
          Enum.reduce(row, {matrix, 0, y}, fn pixel, {matrix, x, y} ->
            matrix =
              if  is_nil(pixel) do
                matrix
              else
                if x > current_position && Enum.count(matrix[0]) + current_position > x do
                  put_in(matrix[y][x - current_position], [255, 142, 198])
                else
                  matrix
                end
              end

            {matrix, x + 1, y}
          end)

        {matrix, y + 1}
      end)

    matrix
  end

  def update(%Game{level: level} = game) do
    level = %Level{level | bad_guys: Enum.map(level.bad_guys, fn bad_guy -> BadGuy.update(bad_guy) end)}
    %Game{game | level: level}
  end

  defp init_bad_guys(1) do
    level_1_color = [0, 0, 0]
    [
      %BadGuy{x_position: 11, y_position: 3,  min_position: 11, max_position: 13, direction: :right, color: level_1_color},
      %BadGuy{x_position: 15, y_position: 6,  min_position: 0, max_position: 15, direction: :left, color: level_1_color},
      %BadGuy{x_position: 21, y_position: 6,  min_position: 17, max_position: 21, direction: :left, color: level_1_color},
      %BadGuy{x_position: 27, y_position: 6,  min_position: 27, max_position: 32, direction: :right, color: level_1_color},
      %BadGuy{x_position: 32, y_position: 6,  min_position: 27, max_position: 32, direction: :left, color: level_1_color},
      %BadGuy{x_position: 46, y_position: 3,  min_position: 46, max_position: 47, direction: :right, color: level_1_color},
      %BadGuy{x_position: 52, y_position: 6,  min_position: 52, max_position: 75, direction: :right, color: level_1_color},
      %BadGuy{x_position: 75, y_position: 6,  min_position: 52, max_position: 75, direction: :left, color: level_1_color},
      %BadGuy{x_position: 97, y_position: 3,  min_position: 97, max_position: 99, direction: :right, color: level_1_color},
      %BadGuy{x_position: 101, y_position: 6,  min_position: 94, max_position: 101, direction: :left, color: level_1_color},
      %BadGuy{x_position: 99, y_position: 6,  min_position: 94, max_position: 101, direction: :left, color: level_1_color}
    ]
  end

  defp init_bad_guys(2) do
    [
      %BadGuy{x_position: 11, y_position: 6,  min_position: 2, max_position: 11, direction: :left, color: [252, 188, 176]},
      %BadGuy{x_position: 9, y_position: 6,  min_position: 3, max_position: 11, direction: :left, color: [252, 188, 176]},
      %BadGuy{x_position: 30, y_position: 6,  min_position: 25, max_position: 43, direction: :left, color: [252, 188, 176]},
      %BadGuy{x_position: 38, y_position: 6,  min_position: 25, max_position: 43, direction: :left, color: [252, 188, 176]},
      %BadGuy{x_position: 42, y_position: 6,  min_position: 25, max_position: 43, direction: :left, color: [252, 188, 176]}
    ]
  end

  defp init_bad_guys(_), do: []

  # nil: all free
  # 1: block
  # 2: hole => deat TODO: perhaps we dont need these
  def level_blocks(1) do
    [
      # row 1
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 2
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 3
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 4
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 5
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil, # 30
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 6
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil, #30
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        nil,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        nil,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 7
      [
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil, #30
        nil,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        1,
        1,
        1,
        nil,
        1,
        1,
        1,
        nil,
        nil,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        1,
        nil,
        1,
        1,
        1,
        1,
        1,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil,
        nil
      ],
      # row 8
      [
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        nil,
        nil,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        nil,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        nil,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1
      ]
    ]
  end

  def level_blocks(2) do
    [
      # row 1
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 2
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       1, 1, nil, 1, 1, 1, nil, 1, 1, 1, nil, nil, nil, 1, 1,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 3
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       1, nil, nil, nil, nil, 1, nil, nil, 1, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, 1, nil, nil, nil, nil, nil, nil, nil, 1, nil,
       nil, nil, nil, nil, nil, nil, nil, 1, 1, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 4
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, 1, nil, 1, 1, 1, nil, 1, nil, nil,
       1, nil, nil, nil, nil, 1, nil, nil, 1, nil, nil, nil, nil, nil, nil,
       nil, 1, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, 1, 1, 1, 1, 1, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 5
      [nil, nil, nil, nil, nil, nil, 1, 1, 1, 1, nil, nil, nil, nil, 1,
       1, nil, nil, nil, nil, nil, 1, 1, 1, nil, 1, 1, 1, nil, nil,
       1, 1, nil, 1, 1, 1, nil, nil, 1, 1, nil, nil, 1, 1, 1,
       nil, 1, 1, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, 1, nil, nil, nil, nil, 1, 1, 1, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, 1, 1, 1, 1, 1, 1, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 6
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1, 1,
       1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1,
       nil, nil, 1, nil, nil, nil, nil, nil, nil, nil, 1, nil, nil, nil, nil,
       nil, nil, 1, 1, nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, nil, 1, nil, 1,
       nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 7
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1, 1, 1,
       1, 1, 1, nil, nil, nil, nil, nil, nil, 1, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 1,
       nil, nil, 1, nil, nil, nil, 1, nil, nil, nil, 1, nil, nil, nil, nil,
       nil, 1, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, nil, 1, nil, 1,
       nil, 1, nil, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      # row 8
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
       1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
       1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, nil,
       nil, nil, 1, 1, 1, 1, 1, nil, 1, 1, 1, 1, 1, 1, 1,
       1, 1, 1, 1, 1, 1, 1, 1, nil, nil, 1, nil, 1, 1, 1,
       1, 1, 1, 1, nil, nil, nil, nil, 1, 1, 1, nil, nil, 2, nil,
       nil, 1, 1, 1, nil, 1, 1, 1, nil, 1, 1, 1, nil, 1, 1,
       1, nil, 1, 1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
    ]
  end

  def level_blocks(_) do
    [
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil],
      [nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
       nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil]
    ]
  end

  defp init_mario_start_y_position(1), do: 6
  defp init_mario_start_y_position(2), do: 0
  defp init_mario_start_y_position(_), do: 6

  defp load_pixels(level), do: PngFile.load_image_for_level(level)
end
