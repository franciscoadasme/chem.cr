module Chem::DX
  @[IO::FileType(format: DX, ext: %w(dx))]
  class Reader < Spatial::Grid::Reader
    include IO::AsciiParser

    def info : Spatial::Grid::Info
      skip_comments
      skip_words 5
      ni, nj, nk = read_int, read_int, read_int
      skip_word # origin
      origin = read_vector
      skip_word # delta
      i = read_vector * (ni - 1)
      skip_word # delta
      j = read_vector * (nj - 1)
      skip_word # delta
      k = read_vector * (nk - 1)
      skip_lines 3

      bounds = Spatial::Bounds.new origin, i, j, k
      Spatial::Grid::Info.new bounds, {ni, nj, nk}
    end

    def read_entry : Spatial::Grid
      Spatial::Grid.build(info) do |buffer, size|
        size.times do |i|
          buffer[i] = read_float
        end
      end
    end

    private def skip_comments : Nil
      while peek == '#'
        skip_line
      end
    end
  end

  @[IO::FileType(format: DX, ext: %w(dx))]
  class Writer < IO::Writer(Spatial::Grid)
    def write(grid : Spatial::Grid) : Nil
      check_open
      write_header grid
      write_connections grid
      write_array grid
    end

    private def write_array(grid : Spatial::Grid) : Nil
      formatl "object 3 class array type double rank 0 items %d data follows", grid.size
      grid.each_with_index do |ele, i|
        format "%16.8f", ele
        @io << '\n' if (i + 1) % 3 == 0
      end
      @io << '\n' unless grid.size % 3 == 0
    end

    private def write_connections(grid : Spatial::Grid) : Nil
      formatl "object 2 class gridconnections counts %d %d %d", grid.ni, grid.nj, grid.nk
    end

    private def write_header(grid : Spatial::Grid) : Nil
      rx, ry, rz = grid.resolution

      formatl "object 1 class gridpositions counts %d %d %d", grid.ni, grid.nj, grid.nk
      formatl "origin%8.3f%8.3f%8.3f", grid.origin.x, grid.origin.y, grid.origin.z
      formatl "delta %8.3f%8.3f%8.3f", rx, 0, 0
      formatl "delta %8.3f%8.3f%8.3f", 0, ry, 0
      formatl "delta %8.3f%8.3f%8.3f", 0, 0, rz
    end
  end
end
