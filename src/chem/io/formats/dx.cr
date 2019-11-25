module Chem::DX
  @[IO::FileType(format: DX, ext: [:dx])]
  class Parser < IO::Parser(Spatial::Grid)
    include IO::AsciiParser

    def parse : Spatial::Grid
      skip_comments
      dim, bounds = read_header
      Spatial::Grid.build(dim, bounds) do |buffer|
        (dim[0] * dim[1] * dim[2]).times do |i|
          buffer[i] = read_float
        end
      end
    end

    private def read_header : Tuple(Spatial::Grid::Dimensions, Bounds)
      skip_words 5
      nx, ny, nz = read_int, read_int, read_int
      skip_word # origin
      origin = read_vector
      skip_word # delta
      a = read_vector
      skip_word # delta
      b = read_vector
      skip_word # delta
      c = read_vector
      skip_lines 3

      size = Spatial::Size[a.size * (nx - 1), b.size * (ny - 1), c.size * (nz - 1)]
      { {nx, ny, nz}, Bounds.new(origin, size) }
    end

    private def skip_comments : Nil
      while peek == '#'
        skip_line
      end
    end
  end

  @[IO::FileType(format: DX, ext: [:dx])]
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
