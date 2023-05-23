@[Chem::RegisterFormat(ext: %w(.dx))]
module Chem::DX
  class Reader
    include FormatReader(Spatial::Grid)
    include FormatReader::Headed(Spatial::Grid::Info)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Spatial::Grid
      Spatial::Grid.build(
        read_header,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
      ) do |buffer, size|
        i = 0
        @pull.each_line do
          while i < size && !@pull.consume_token.eol?
            buffer[i] = @pull.float
            i += 1
          end
        end
      end
    end

    protected def decode_header : Spatial::Grid::Info
      @pull.each_line do
        break unless @pull.consume_token.char == '#'
      end

      4.times { @pull.consume_token }
      ni, nj, nk = @pull.next_i, @pull.next_i, @pull.next_i
      @pull.consume_line
      @pull.consume_token # skip origin word
      origin = Spatial::Vec3[@pull.next_f, @pull.next_f, @pull.next_f]
      @pull.consume_line
      vi, vj, vk = {ni, nj, nk}.map do |n|
        @pull.consume_token # skip delta word
        delta = Spatial::Vec3[@pull.next_f, @pull.next_f, @pull.next_f]
        @pull.consume_line
        delta * (n - 1)
      end
      2.times { @pull.consume_line }

      bounds = Spatial::Parallelepiped.new vi, vj, vk, origin
      Spatial::Grid::Info.new bounds, {ni, nj, nk}
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)

    protected def encode_entry(obj : Spatial::Grid) : Nil
      check_open
      write_header obj
      write_connections obj
      write_array obj
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
