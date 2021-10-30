module Chem::VASP
  module GridReader
    def read_attached : Structure
      read_header
      @attached || raise "BUG: @attached is nil after reading header"
    end

    protected def decode_attached : Structure
      Structure.from_poscar(@io)
    end

    protected def decode_header : Spatial::Grid::Info
      @attached = decode_attached
      raise "BUG: unit cell cannot be nil" unless cell = @attached.try(&.cell)

      @pull.next_line
      nx, ny, nz = @pull.next_i, @pull.next_i, @pull.next_i
      Spatial::Grid::Info.new cell.bounds, {nx, ny, nz}
    end

    private def read_array(info : Spatial::Grid::Info,
                           & : Float64 -> Float64) : Spatial::Grid
      nx, ny, nz = info.dim
      nyz = ny * nz
      Spatial::Grid.build(
        info,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
      ) do |buffer|
        nz.times do |k|
          ny.times do |j|
            nx.times do |i|
              @pull.next_token || (@pull.next_line && @pull.next_token)
              buffer[i * nyz + j * nz + k] = yield @pull.float
            end
          end
        end
      end
    end
  end

  module GridWriter
    @write_header = true

    def initialize(@io : IO, @structure : Structure, @sync_close : Bool = false)
    end

    # Writes a formatted number to the IO following Fortran's scientific
    # notation convention.
    #
    # Numbers always start with a leading zero (e.g., "0.123E+00" vs
    # "1.230E-01"), which is replaced by a minus sign for negative
    # numbers (e.g., "-.123" vs "-0.123"). This ensures that the minus
    # sign doesn't change number width, e.g., "0.123" and "-.123".
    private def format_array_element(value : Float64) : Nil
      if value == 0
        @io.printf "%18.11E", value
      else
        s = sprintf "%.10E", value
        if value > 0
          exp = s[13..].to_i + 1
          @io << " 0." << s[0] << s[2..11]
        else
          exp = s[14..].to_i + 1
          @io << " -." << s[1] << s[3..12]
        end
        @io << 'E'
        @io << (exp < 0 ? '-' : '+')
        @io.printf "%02d", exp.abs
      end
    end

    private def incompatible_expcetion : Nil
      raise ArgumentError.new("Incompatible structure and grid")
    end

    private def write_array(grid : Spatial::Grid, & : Float64 -> Float64) : Nil
      @io.puts
      nx, ny, nz = grid.dim
      formatl "%5d%5d%5d", nx, ny, nz
      grid.size.times do |i_|
        i = i_ % nx
        j = (i_ // nx) % ny
        k = i_ // (ny * nx)
        format_array_element(yield grid.unsafe_fetch({i, j, k}))
        @io << '\n' if (i_ + 1) % 5 == 0
      end
      @io << '\n' unless grid.size % 5 == 0
    end

    private def write_header : Nil
      return unless @write_header
      @structure.to_poscar(@io)
      @write_header = false
    end
  end
end
