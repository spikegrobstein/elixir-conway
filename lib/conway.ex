defmodule Conway do

  @moduledoc """
  Any live cell with fewer than two live neighbours dies, as if caused by under-population.
  Any live cell with two or three live neighbours lives on to the next generation.
  Any live cell with more than three live neighbours dies, as if by overcrowding.
  Any dead cell with exactly three live neighbours becomes a live cell, as if by reproduction.
  """

  @default_width 10
  @default_height 10

  # the conway life board
  # has a width, a height, generation counter and a field
  # field is a list of `cell_state` pids
  defrecord Board, width: 0, height: 0, generation: 1, field: nil

  @doc """
  return a Board record with the default width and height
  """
  def generate_board() do
    generate_board @default_width, @default_height
  end

  @doc """
    returns a board Record with the given dimensions

  """
  def generate_board( width, height ) do
    # seed the random number generator with a timestamp
    :random.seed :erlang.now

    # create the field
    field = build_field( width * height )

    Board.new width: width, height: height, field: field
  end

  # return a list of true/false cells for the given length.
  def build_field( length ) when length > 0 do
    Enum.map 1..length, fn(_) -> new_cell end
  end

  @doc"""
  a process, called via spawn(), that tracks individual cell's states
  messages are sent to it to either query it's state, using the `:state` tuple
  or telling it to update its state using the `:neighbors` tuple.

  `generation` keeps track of this cell's current generation to prevent
  false updates when receiving messages more than once

  `last_update` keeps track of the last generation that this cell updated

  `state` is a boolean of whether this cell is alive or not.
  """
  def cell_state( generation, last_update, state ) do
    receive do
      { :state, sender } ->
        sender <- { :cell, generation, last_update, state }
        cell_state( generation, last_update, state )

      { :neighbors, current_generation, count } when current_generation > generation ->
        # if it's a new generation
        # should probably send the state back to the sender so I don't need to query manually
        new_state = apply_rule( state, count )
        new_last_update = if state == new_state do
            last_update
          else
            current_generation
          end

        cell_state current_generation, new_last_update, new_state

      { :neighbors, _current_generation, _count } ->
        # it's a repeat of an old generation, so don't do anything
        cell_state generation, last_update, state

      anything ->
        IO.puts "Got bullshit in cell_state: #{ inspect anything }"
        System.halt(1)
    end
  end


  # spawns a new cell_state process and initializes it with a random state
  # returning the pid
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
  step through one generation of the board, returning the board with the updated generation.
  """
  def step( board ) do
    # collect all the neightbor counts for each cell
    neighbors = collect_neighbors( board )

    # push that info into the cells
    update_state board, neighbors

    # increment the board's generation
    board.generation board.generation + 1
  end

  @doc """
  returns a list of tuples in the format:
  { cell_pid, neighbor_count }
  """
  def collect_neighbors(board) do

    # spawn a bunch of counters, passing self to them
    # in a receive block, retrieve them all, counting until we have them all
    # then return the full list

    # spawn a collector process
    collector = spawn( Conway, :do_collect_neighbors, [board, self, []])

    # iterate through the cells, spawning processes to count the neighbors
    Enum.reduce board.field, 0, fn(cell_pid, offset) ->
      spawn(Conway, :count_neighbors, [ board, offset, cell_pid, collector ])
      offset + 1
    end

    receive do
      list ->
        # IO.puts "Got back list: #{ inspect list }"
        list
    end

  end

  # acc is a list of the neighbor tuples as { cell_pid, neighbor_count }
  def do_collect_neighbors( board = Board[width: width ,height: height], callback_pid, acc ) when length(acc) < width * height do
    receive do
      { cell_pid, neighbor_count } ->
        # IO.puts "do_collect_neighbors; got #{ inspect cell_pid } | #{ neighbor_count } | #{ length acc }"
        do_collect_neighbors( board, callback_pid, [ { cell_pid, neighbor_count } | acc ])
      anything ->
        IO.puts "do_collect_neighbors ERROR: #{ anything }"
        System.halt(2)
    end
  end

  def do_collect_neighbors( _board, callback_pid, acc) do
    callback_pid <- acc
  end

  def update_state( board, neighbors ) do
    Enum.each neighbors, fn( {cell_pid, neighbor_count } ) ->
      cell_pid <- { :neighbors, board.generation, neighbor_count }
    end
  end

  @doc """
  go through board, spit out rows with either * or _ for live for dead cells, repectively
  """
  def print_board( board ) do
    do_print_board( board, board.field, [] )
  end

  defp do_print_board( board, [], output ) do
    output
      |> Enum.reverse
      |> Enum.join
      |> IO.puts
    IO.puts "G: #{ board.generation }"
    IO.puts ""
    IO.puts ""
  end
  
  # 1234567890N
  defp do_print_board( board, [ cell | list ], output) do
    # print the line and set line to empty list if it's the width of the board.
    output = if rem(length(output) + 1, board.width + 1) == 0 do
      [ "\n" | output ]
    else
      output
    end

    cell <- { :state, self }
    receive do
      { :cell, _generation, _last_updated, state } ->
        do_print_board( board, list, [ do_print_cell(state) | output ])
    end
  end

  # cell characters.
  defp do_print_cell( true ), do: '*'
  defp do_print_cell( false ), do: '_'

  @doc """
    given the board and an offset, return the number of neighbors this cell has.
  """
  def count_neighbors( board, offset, cell_pid, collector ) do
    { width, height, field } = { board.width, board.height, board.field }

    

    # should be an array of pids
    neighbors = neighbor_offsets( offset, width, height )
      |> Enum.map fn( offset ) -> Enum.at( field, offset ) end


    count = Enum.reduce neighbors, 0, fn(collected_cell_pid, acc) ->
      collected_cell_pid <- { :state, self }

      # count up the neighbors;
      # increment accumulator when cell is alive
      # don't touch the accumulator when cell is dead
      receive do
        { :cell, _, _, true } ->
          acc + 1
        { :cell, _, _, false } ->
          acc
      end
    end

    collector <- { cell_pid, count }
  end

  @doc """
  given the board's dimensions and an offset, return the offset in the board.field for the given offset
  this is where wrapping of the board is handled.
  """

  # 00 01 02 03 04
  # 05 06 07 08 09
  # 10 11 12 13 14
  # 15 16 17 18 19

  def offset_to_xy( offset, width, _height ), do: { rem( offset, width ), div( offset, width ) }

  # translate an x,width or y,height to wrapping x or y
  def tr_coord( coord, dimension ) when coord >= 0 and coord < dimension, do: coord
  def tr_coord( coord, dimension ) when coord == dimension,               do: 0
  def tr_coord( -1, dimension ),                                          do: dimension - 1

  def xy_to_offset( x, y, width, height ) do
    x = tr_coord( x, width )
    y = tr_coord( y, height )

    x + ( y * width )
  end

  # return a list of neighbor offsets for the given offset
  def neighbor_offsets( offset, width, height ) do
    neighbor_coords( offset, width, height )
      |> Enum.map fn( { x, y } ) -> xy_to_offset( x, y, width, height ) end
  end

  def neighbor_coords( offset, width, height ) do
    { x, y } = offset_to_xy( offset, width, height )

    neighbor_coords( x, y )
  end

  def neighbor_coords( x, y ) do
    [
      { x - 1, y - 1 },
      { x, y - 1 },
      { x + 1, y - 1 },
      { x - 1, y },
      { x + 1, y },
      { x - 1, y + 1 },
      { x, y + 1 },
      { x + 1, y + 1 }
    ]
  end

  # the actual rules for the game.
  def apply_rule( true, neighbor_count ) when neighbor_count < 2, do: false
  def apply_rule( true, neighbor_count ) when neighbor_count <= 3, do: true
  def apply_rule( true, neighbor_count ) when neighbor_count > 3, do: false
  def apply_rule( false, neighbor_count ) when neighbor_count == 3, do: true
  def apply_rule( state, _ ), do: state

end

