@[Chem::FileType(ext: %w(cube))]
module Chem::Cube
  class Reader
    include FormatReader(Spatial::Grid)
    include TextFormatReader

    BOHR_TO_ANGS = 0.529177210859

    def read(type : Spatial::Grid.class) : Spatial::Grid
      check_open
      check_eof skip_lines: false
      Spatial::Grid.build(read_info(Spatial::Grid)) do |buffer, size|
        size.times do |i|
          buffer[i] = @io.read_float
        end
      end
    end

    def read_info(type : Spatial::Grid.class) : Spatial::Grid::Info
      2.times { @io.skip_line }
      n_atoms = @io.read_int
      parse_exception "Cube with multiple densities not supported" if n_atoms < 0

      origin = @io.read_vector * BOHR_TO_ANGS
      nx, vi = @io.read_int, @io.read_vector * BOHR_TO_ANGS
      ny, vj = @io.read_int, @io.read_vector * BOHR_TO_ANGS
      nz, vk = @io.read_int, @io.read_vector * BOHR_TO_ANGS
      (n_atoms + 1).times { @io.skip_line }

      bounds = Spatial::Bounds.new origin, vi * nx, vj * ny, vk * nz
      Spatial::Grid::Info.new bounds, {nx, ny, nz}
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)

    ANGS_TO_BOHR = 1.88972612478289694072

    needs atoms : AtomCollection

    def write(grid : Spatial::Grid) : Nil
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