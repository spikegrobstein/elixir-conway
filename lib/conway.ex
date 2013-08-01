defmodule Conway do

  @moduledoc """
  Any live cell with fewer than two live neighbours dies, as if caused by under-population.
  Any live cell with two or three live neighbours lives on to the next generation.
  Any live cell with more than three live neighbours dies, as if by overcrowding.
  Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
  """

  @default_width 10
  @default_height 10

  defrecord Board, width: 0, height: 0, field: nil

  @doc """
  return a Board record with the default width and height
  """
  def generate_board() do
    generate_board @default_width, @default_height
  end

  @doc """
    returns a board Record

  """
  def generate_board( width, height ) do
    field = build_field( width * height, [] )

    Board.new width: width, height: height, field: field
  end

  # return a list of true/false cells for the given length.
  def build_field( length, acc ) when length > 0 do
    build_field length - 1, [ new_cell( length(acc) ) | acc ]
  end

  def build_field( 0, acc ) do
    acc
  end


  # returns a tuple representing a cell and assigns it the given index (for sorting in the field)
  # tuple is in format of:
  # { :cell, index, true||false }
  defp new_cell( index ) do
    { :cell, index, :random.uniform > 0.5 }
  end

  @doc """
  print the board out and step through lifecycles indefinitely

    iex> Conway.run Conway.generate_board(75, 30)
  """
  def run( board ) do
    print_board board
    # :timer.sleep 100
    board
      |> step
      |> run
  end

  @doc """
  step through one generation of the board, returning the board with the updated field.
  """
  def step( board ) do
    field = do_step( board, board.field, [] )
    board.field field
  end

  defp do_step( _board, [], acc ) do
    Enum.reverse acc
  end

  defp do_step( board, [ current | field ], acc ) do
    { :cell, index, state } = current

    updated_cell_state = apply_rule( state, count_neighbors( board, length(acc) ))

    cell = { :cell, index, updated_cell_state }

    do_step board, field, [ cell | acc ]
  end

  @doc """
  go through board, spit out rows with either * or _ for live for dead cells, repectively
  """
  def print_board( board ) do
    do_print_board( board, board.field, [] )
    IO.puts ""
    IO.puts ""
  end

  defp do_print_board( board, [], line ) do
    IO.puts Enum.join(line)
  end

  defp do_print_board( board, [ cell | list ], line) do
    # print the line and set line to empty list if it's the width of the board.
    line = if length(line) == board.width do
      IO.puts Enum.join(line)
      []
    else
      line
    end

    do_print_board( board, list, [ do_print_cell(cell) | line ])
  end

  # cell characters.
  defp do_print_cell( { :cell, _, true } ), do: '*'
  defp do_print_cell( { :cell, _, false } ), do: '_'

  @doc """
    given the board and an offset, return the number of neighbors this cell has.
  """
  def count_neighbors( board, offset ) do
    { width, height, field } = { board.width, board.height, board.field }

    neighbors = [
      Enum.at( field, offset_for(offset - width - 1, width, height) ),
      Enum.at( field, offset_for(offset - width, width, height) ),
      Enum.at( field, offset_for(offset - width + 1, width, height) ),
      Enum.at( field, offset_for(offset - 1, width, height) ),
      Enum.at( field, offset_for(offset + 1, width, height) ),
      Enum.at( field, offset_for(offset + width - 1, width, height) ),
      Enum.at( field, offset_for(offset + width, width, height) ),
      Enum.at( field, offset_for(offset + width + 1, width, height) )
    ]

    Enum.count neighbors, fn(x) ->
      { :cell, _index, state } = x
      state
    end
  end

  @doc """
  given the board and an offset, return the offset in the board.field for the given offset
  this is where wrapping of the board is handled.
  """
  def offset_for( offset, width, height ) when offset < 0, do: ( (width * height) + offset )
  def offset_for( offset, width, height ) when offset > (width * height - 1), do: ( offset - (width * height) )
  def offset_for( offset, _, _ ), do: offset

  # the actual rules for the game.
  def apply_rule( true, neighbor_count ) when neighbor_count < 2, do: false
  def apply_rule( true, neighbor_count ) when neighbor_count <= 3, do: true
  def apply_rule( true, neighbor_count ) when neighbor_count > 3, do: false
  def apply_rule( false, neighbor_count ) when neighbor_count == 3, do: true
  def apply_rule( state, _ ), do: state

end

