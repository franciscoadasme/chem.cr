module Chem::DX
  @[IO::FileType(format: DX, ext: %w(dx))]
  class Parser < Spatial::Grid::Parser
    include IO::AsciiParser

    def info : Spatial::Grid::Info
      skip_comments
      skip_words 5
      nx, ny, nz = read_int, read_int, read_int
      skip_word # origin
      origin = read_vector
      skip_word # delta
      i = read_vector
      skip_word # delta
      j = read_vector
      skip_word # delta
      k = read_vector
      skip_lines 3

      size = Spatial::Size[i.size * (nx - 1), j.size * (ny - 1), k.size * (nz - 1)]
      Spatial::Grid::Info.new Spatial::Bounds.new(origin, size), {nx, ny, nz}
    end

    def parse : Spatial::Grid
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
      i = 0
      grid.each do |ele|
        i += 1
        format "%16.8f", ele
        @io << '\n' if i % 3 == 0
      end
      @io << '\n' unless i % 3 == 0
    end

    private def write_connections(grid : Spatial::Grid) : Nil
      formatl "object 2 class gridconnections counts %d %d %d", grid.nx, grid.ny, grid.nz
    end

    private def write_header(grid : Spatial::Grid) : Nil
      rx, ry, rz = grid.resolution

      formatl "object 1 class gridpositions counts %d %d %d", grid.nx, grid.ny, grid.nz
      formatl "origin%8.3f%8.3f%8.3f", grid.origin.x, grid.origin.y, grid.origin.z
      formatl "delta %8.3f%8.3f%8.3f", rx, 0, 0
      formatl "delta %8.3f%8.3f%8.3f", 0, ry, 0
      formatl "delta %8.3f%8.3f%8.3f", 0, 0, rz
    end
  end
end
