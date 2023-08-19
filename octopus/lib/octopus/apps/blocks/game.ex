defmodule Octopus.Apps.Blocks.Game do
  alias Octopus.Canvas

  defstruct tile: nil,
            board: Canvas.new(8, 16),
            score: 0,
            layout: %{},
            moved: false,
            actions: %{},
            t: 1

  alias Phoenix.LiveDashboard.TitleBarComponent
  alias Octopus.Font
  alias Octopus.Sprite
  alias Octopus.JoyState
  alias Octopus.Apps.Blocks
  alias Blocks.Game

  defmodule Tile do
    defstruct pos: {2, -2}, index: 0, rotations: [], col: nil, t_rem: 20

    def new(rotations, col) do
      %Tile{
        rotations: rotations,
        col: col
      }
    end

    def tile_canvas(%Tile{index: index, rotations: rotations, col: col}) do
      rotations
      |> Enum.at(index)
      |> Enum.with_index()
      |> Enum.reduce(Canvas.new(4, 4), fn {row, y}, acc ->
        row
        |> Enum.with_index()
        |> Enum.reduce(acc, fn
          {0, _}, acc -> acc
          {1, x}, acc -> acc |> Canvas.put_pixel({x, y}, col)
        end)
      end)
    end

    def move(%Tile{pos: {x, y}} = tile) do
      %Tile{
        tile
        | pos: {x, y + 1}
      }
    end

    def move_left(%Tile{pos: {x, y}} = tile) do
      %Tile{
        tile
        | pos: {x - 1, y}
      }
    end

    def move_right(%Tile{pos: {x, y}} = tile) do
      %Tile{
        tile
        | pos: {x + 1, y}
      }
    end

    def rotate(%Tile{} = tile) do
      %Tile{tile | index: rem(tile.index + 1, length(tile.rotations))}
    end
  end

  @tiles Code.eval_string("""
         [
          [
           [[0, 0, 0, 0],
            [0, 0, 0, 0],
            [0, 0, 1, 1],
            [0, 1, 1, 0]],
           [[0, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 1, 1, 0],
            [0, 0, 1, 0]]
          ],
          [
           [[0, 1, 0, 0],
            [0, 1, 0, 0],
            [0, 1, 0, 0],
            [0, 1, 0, 0]],
           [[0, 0, 0, 0],
            [0, 0, 0, 0],
            [1, 1, 1, 1],
            [0, 0, 0, 0]]
           ],
           [
            [[0, 0, 0, 0],
             [0, 0, 0, 0],
             [0, 1, 1, 0],
             [0, 1, 1, 0]]
           ],
           [
            [[0, 0, 0, 0],
             [0, 0, 0, 0],
             [1, 1, 0, 0],
             [0, 1, 1, 0]],
            [[0, 0, 0, 0],
             [0, 0, 1, 0],
             [0, 1, 1, 0],
             [0, 1, 0, 0]]
           ],
           [
            [[0, 0, 0, 0],
             [0, 0, 0, 0],
             [0, 1, 0, 0],
             [1, 1, 1, 0]],
            [[0, 0, 0, 0],
             [0, 1, 0, 0],
             [0, 1, 1, 0],
             [0, 1, 0, 0]],
             [[0, 0, 0, 0],
             [0, 1, 0, 0],
             [1, 1, 0, 0],
             [0, 1, 0, 0]],
             [[0, 0, 0, 0],
             [0, 0, 0, 0],
             [1, 1, 1, 0],
             [0, 1, 0, 0]],
           ],
          ]
         """)
         |> elem(0)

  @colors [
    {219, 59, 57},
    {235, 155, 62},
    {248, 226, 76},
    {106, 181, 85},
    {84, 170, 221},
    {36, 87, 153},
    {135, 47, 136}
  ]

  def new_tile() do
    Tile.new(
      @tiles |> Enum.random(),
      @colors |> Enum.random()
    )
  end

  def new(args) do
    title = Canvas.from_string("T", Font.load("robot"))

    %Game{
      tile: new_tile(),
      layout:
        case args[:layout] do
          nil ->
            unless args[:side] == :right do
              %{
                base_canvas: Canvas.new(40, 8) |> Canvas.overlay(title),
                score_base: 16,
                playfield_base: 8 * 3,
                playfield_channel: 5,
                playfield_rotation: :cw,
                button_map: %{u: :right, d: :left, r: :down, l: :drop, a: :rotate}
              }
            else
              %{
                base_canvas:
                  Canvas.new(40, 8)
                  |> Canvas.overlay(title, offset: {4 * 8, 0}),
                score_base: 24,
                playfield_base: 0,
                playfield_channel: 6,
                playfield_rotation: :ccw,
                button_map: %{d: :right, u: :left, l: :down, r: :drop, a: :rotate}
              }
            end

          layout when layout != nil ->
            layout
        end
    }
  end

  def tile_hits?(board, tile) do
    tile_canvas = tile_board_overlay(tile)

    hit = tile_canvas.pixels |> Enum.any?(fn {pos, _} -> board.pixels |> Map.get(pos) end)
    {width, height} = {board.width, board.height}

    out_of_bounds =
      tile_canvas.pixels |> Enum.any?(fn {{x, y}, _} -> y >= height || x < 0 || x >= width end)

    hit || out_of_bounds
  end

  def tile_board_overlay(tile) do
    Canvas.new(8, 16) |> Canvas.overlay(Tile.tile_canvas(tile), offset: tile.pos)
  end

  def move_or_place_tile(%Game{} = game) do
    moved_tile = game.tile |> Tile.move()

    new_game =
      if tile_hits?(game.board, moved_tile) do
        %Game{
          game
          | tile: new_tile(),
            board: game.board |> Canvas.overlay(tile_board_overlay(game.tile))
        }
      else
        %Game{game | tile: moved_tile}
      end

    # new_game.board
    # |> IO.inspect()

    new_game
  end

  def check_gameover(%Game{tile: tile, board: board} = game) do
    if tile_hits?(board, tile) do
      new(layout: game.layout)
    else
      game
    end
  end

  defp take_tile_if_possible(%Game{} = game, action, %Tile{} = new_tile) do
    #    IO.inspect({:take, game.actions, action, new_tile})

    unless tile_hits?(game.board, new_tile) do
      %Game{game | tile: new_tile, actions: Map.put(game.actions, action, game.t)}
    else
      game
    end
  end

  defp try_action(:down = action, game) do
    %Game{
      (game
       |> move_or_place_tile())
      | actions: Map.put(game.actions, action, game.t)
    }
    ## todo needs a better place
    |> check_gameover()
  end

  defp try_action(:rotate = action, game) do
    new_tile = Tile.rotate(game.tile)

    game
    |> take_tile_if_possible(action, new_tile)
  end

  defp try_action(:left = action, game) do
    new_tile = Tile.move_left(game.tile)

    game
    |> take_tile_if_possible(action, new_tile)
  end

  defp try_action(:right = action, game) do
    new_tile = Tile.move_right(game.tile)

    game
    |> take_tile_if_possible(action, new_tile)
  end

  defp try_action(_action, game), do: game

  def clear_non_desired_actions(%Game{} = game, actions) do
    %Game{
      game
      | actions:
          game.actions
          |> Enum.reject(fn
            {:down, old_t} -> game.t - old_t > 4
            {k, _v} -> !(k in actions)
          end)
          |> Enum.into(%{})
    }
  end

  def tick(%Game{} = game, %JoyState{} = joy) do
    desired_actions =
      joy.buttons
      |> Enum.map(fn btn -> game.layout.button_map[btn] end)
      |> Enum.reject(fn action -> is_nil(action) end)

    new_game =
      game
      |> clear_non_desired_actions(desired_actions)

    new_game =
      desired_actions
      |> Enum.reject(fn k -> Map.get(new_game.actions, k) end)
      |> Enum.reduce(new_game, &try_action/2)

    %Game{
      case rem(new_game.t, 60) do
        0 ->
          new_game
          |> move_or_place_tile()
          |> check_gameover()

        _ ->
          new_game
      end
      | t: new_game.t + 1
    }
  end

  def render_canvas(%Game{layout: layout} = game) do
    [first, second] =
      game.score |> to_string() |> String.pad_leading(2, "0") |> String.to_charlist()

    font = Font.load("robot")
    font_variant = 8

    gamecanvas =
      game.board
      |> Canvas.overlay(Tile.tile_canvas(game.tile), offset: game.tile.pos)
      |> Canvas.rotate(layout.playfield_rotation)

    canvas =
      layout.base_canvas
      |> Canvas.overlay(gamecanvas, offset: {layout.playfield_base, 0})
      |> Font.pipe_draw_char(font, second, font_variant, {layout.score_base, 0})
      |> (fn c ->
            unless first == ?0 do
              c |> Font.pipe_draw_char(font, first, font_variant, {layout.score_base - 8, 0})
            else
              c
            end
          end).()

    canvas
  end
end
