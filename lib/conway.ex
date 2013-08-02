defmodule Conway do

  @moduledoc """
  Any live cell with fewer than two live neighbours dies, as if caused by under-population.
  Any live cell with two or three live neighbours lives on to the next generation.
  Any live cell with more than three live neighbours dies, as if by overcrowding.
  Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
  """

  @default_width 10
  @default_height 10

  defrecord Board, width: 0, height: 0, generation: 1, field: nil

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
    field = build_field( width * height )

    Board.new width: width, height: height, field: field
  end

  # return a list of true/false cells for the given length.
  def build_field( length ) when length > 0 do
    Enum.map 1..length, fn(x) -> new_cell end
  end

  def cell_state( generation, last_update, state ) do
    receive do
      { :state, sender } ->
        sender <- { :cell, generation, last_update, state }
        cell_state( generation, last_update, state )

      { :neighbors, current_generation, count } ->
        # should probably send the state back to the sender so I don't need to query manually
        if current_generation > generation do
          # if it's a new generation
          new_state = apply_rule( state, count )
          new_last_update = if state == new_state do
              last_update
            else
              current_generation
            end

          cell_state current_generation, new_last_update, new_state
        else
          # it's a repeat of an old generation, so don't do anything
          cell_state generation, last_update, state
        end
      anything ->
        IO.puts "Got bullshit in cell_state: #{ inspect anything }"
        System.halt(1)
    end
  end


  # returns a tuple representing a cell and assigns it the given index (for sorting in the field)
  # tuple is in format of:
  # { :cell, index, true||false }
  defp new_cell do
    spawn(Conway, :cell_state, [ 0, 0, :random.uniform > 0.5 ])
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
    { neighbors, acc } = Enum.map_reduce board.field, 0, fn(cell_pid, offset) ->
      # return { cell_pid, neighbor_count }
      { { cell_pid, count_neighbors( board, offset ) }, offset + 1 }
    end

    Enum.each neighbors, fn( {cell_pid, neighbor_count } ) ->
      cell_pid <- { :neighbors, board.generation, neighbor_count }
    end

    board.generation board.generation + 1
  end


  @doc """
  go through board, spit out rows with either * or _ for live for dead cells, repectively
  """
  def print_board( board ) do
    do_print_board( board, board.field, [] )
    IO.puts "G: #{ board.generation }"
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

    cell <- { :state, self }
    receive do
      { :cell, generation, last_updated, state } ->
        do_print_board( board, list, [ do_print_cell(state) | line ])
    end
  end

  # cell characters.
  defp do_print_cell( true ), do: '*'
  defp do_print_cell( false ), do: '_'

  @doc """
    given the board and an offset, return the number of neighbors this cell has.
  """
  def count_neighbors( board, offset ) do
    { width, height, field } = { board.width, board.height, board.field }

    # should be an array of pids
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

    neighbors = Enum.map neighbors, fn(cell_pid) ->
      cell_pid <- { :state, self }

      receive do
        { :cell, _, _, state } ->
          state
      end
    end

    Enum.count neighbors, fn(x) ->
      x
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

