module Chem::VASP
  module GridParser
    def info : Spatial::Grid::Info
      skip_line
      scale = read_float
      i, j, k = scale * read_vector, scale * read_vector, scale * read_vector
      skip_atoms
      nx, ny, nz = read_int, read_int, read_int

      bounds = Spatial::Bounds.new Spatial::Vector.origin, i, j, k
      Spatial::Grid::Info.new bounds, {nx, ny, nz}
    end

    private def read_array(info : Spatial::Grid::Info,
                           & : Float64 -> Float64) : Spatial::Grid
      nx, ny, nz = info.dim
      nyz = ny * nz
      Grid.build(info) do |buffer|
        nz.times do |k|
          ny.times do |j|
            nx.times do |i|
              buffer[i * nyz + j * nz + k] = yield read_float
            end
          end
        end
      end
    end

    private def skip_atoms : Nil
      n_atoms = 0
      n_elements = 0
      loop do
        if (str = read_word)[0].number?
          n_atoms += str.to_i
          n_elements -= 1
          break if n_elements == 0
        else
          n_elements += 1
        end
      end
      skip_line
      skip_line if (char = peek) && char.in_set?("sS")
      skip_line
      n_atoms.times { skip_line }
    end
  end

  module GridWriter
    @write_header = true

    def initialize(input : ::IO | Path | String,
                   @structure : Structure,
                   *,
                   sync_close : Bool = false)
      super input, sync_close: sync_close
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
        format "%18.11E", (yield grid.unsafe_fetch({i, j, k}))
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
