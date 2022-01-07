@[Chem::RegisterFormat(ext: %w(.cube))]
module Chem::Cube
  class Reader
    include FormatReader(Spatial::Grid)
    include FormatReader::Headed(Spatial::Grid::Info)
    include FormatReader::Attached(Structure)

    BOHR_TO_ANGS = 0.529177210859

    @n_atoms = 0

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    def read_attached : Structure
      read_header
      @attached || raise "BUG: @attached is nil after reading header"
    end

    protected def decode_attached : Structure
      Structure.build(
        source_file: (file = @io).is_a?(File) ? file.path : nil,
      ) do |builder|
        @n_atoms.times do
          builder.atom \
            element: (PeriodicTable[@pull.next_i]? || @pull.error("Unknown element")),
            partial_charge: @pull.next_f,
            coords: read_vector
          @pull.next_line
        end
      end
    end

    protected def decode_entry : Spatial::Grid
      Spatial::Grid.build(
        read_header,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
      ) do |buffer, size|
        i = 0
        @pull.each_line do
          while i < size && @pull.next_token
            buffer[i] = @pull.float
            i += 1
          end
        end
      end
    end

    private def decode_header : Spatial::Grid::Info
      2.times { @pull.next_line }

      @pull.next_line
      @n_atoms = @pull.next_i
      @pull.error "Cube with multiple densities not supported" if @n_atoms < 0
      origin = read_vector * BOHR_TO_ANGS
      @pull.next_line
      ni, dvi = @pull.next_i, read_vector * BOHR_TO_ANGS
      @pull.next_line
      nj, dvj = @pull.next_i, read_vector * BOHR_TO_ANGS
      @pull.next_line
      nk, dvk = @pull.next_i, read_vector * BOHR_TO_ANGS
      @pull.next_line

      @attached = decode_attached

      vi, vj, vk = dvi * ni, dvj * nj, dvk * nk
      bounds = Spatial::Parallelepiped.new origin, Spatial::Mat3.basis(vi, vj, vk)
      Spatial::Grid::Info.new bounds, {ni, nj, nk}
    end

    private def read_vector : Spatial::Vec3
      Spatial::Vec3[@pull.next_f, @pull.next_f, @pull.next_f]
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)

    ANGS_TO_BOHR = 1.88972612478289694072

    def initialize(@io : IO, @atoms : AtomCollection, @sync_close : Bool = false)
    end

    protected def encode_entry(grid : Spatial::Grid) : Nil
      check_open
      write_header grid
      write_atoms
      write_array grid
    end

    private def write_array(grid : Spatial::Grid) : Nil
      grid.each_with_index do |ele, i|
        format "%13.5E", ele
        @io << '\n' if (i + 1) % 6 == 0
      end
      @io << '\n' unless grid.size % 6 == 0
    end

    private def write_atoms : Nil
      @atoms.each_atom do |atom|
        formatl "%5d%12.6f%12.6f%12.6f%12.6f",
          atom.atomic_number,
          atom.partial_charge,
          atom.x * ANGS_TO_BOHR,
          atom.y * ANGS_TO_BOHR,
          atom.z * ANGS_TO_BOHR
      end
    end

    private def write_header(grid : Spatial::Grid) : Nil
      origin = grid.origin * ANGS_TO_BOHR
      i = grid.bounds.i / grid.ni * ANGS_TO_BOHR
      j = grid.bounds.j / grid.nj * ANGS_TO_BOHR
      k = grid.bounds.k / grid.nk * ANGS_TO_BOHR

      @io.puts "CUBE FILE GENERATED WITH CHEM.CR"
      @io.puts "OUTER LOOP: X, MIDDLE LOOP: Y, INNER LOOP: Z"
      formatl "%5d%12.6f%12.6f%12.6f", @atoms.n_atoms, origin.x, origin.y, origin.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[0], i.x, i.y, i.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[1], j.x, j.y, j.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[2], k.x, k.y, k.z
    end
  end
end
