module Chem::DX
  @[IO::FileType(Spatial::Grid, format: DX, ext: %w(dx))]
  class Reader
    include IO::Reader(Spatial::Grid)
    include Spatial::Grid::Reader

    def info : Spatial::Grid::Info
      while @io.skip_whitespace.peek == '#'
        @io.skip_line
      end

      5.times { @io.skip_word }
      ni, nj, nk = @io.read_int, @io.read_int, @io.read_int
      @io.skip_word # origin
      origin = @io.read_vector
      vi, vj, vk = {ni, nj, nk}.map { |n| @io.skip_word.read_vector * (n - 1) }
      3.times { @io.skip_line }

      bounds = Spatial::Bounds.new origin, vi, vj, vk
      Spatial::Grid::Info.new bounds, {ni, nj, nk}
    end

    def read : Spatial::Grid
      check_open
      check_eof
      Spatial::Grid.build(info) do |buffer, size|
        size.times do |i|
          buffer[i] = @io.read_float
        end
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
