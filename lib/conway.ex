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
    :random.seed :erlang.now
    field = build_field( width * height )

    Board.new width: width, height: height, field: field
  end

  # return a list of true/false cells for the given length.
  def build_field( length ) when length > 0 do
    Enum.map 1..length, fn(_) -> new_cell end
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
    neighbors = collect_neighbors( board )

    update_state board, neighbors

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

    collector = spawn( Conway, :do_collect_neighbors, [board, self, []])

    Enum.reduce board.field, 0, fn(_cell_pid, offset) ->
      spawn(Conway, :count_neighbors, [ board, offset, collector ])
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

  def do_collect_neighbors( board, callback_pid, acc) do
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
  def count_neighbors( board, offset, collector ) do
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

    neighbors = Enum.map neighbors, fn(collected_cell_pid) ->
      collected_cell_pid <- { :state, self }

      receive do
        { :cell, _, _, state } ->
          state
      end
    end

    count = Enum.count neighbors, fn(x) ->
      x
    end

    cell_pid = Enum.at( field, offset )

    collector <- { cell_pid, count }
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

