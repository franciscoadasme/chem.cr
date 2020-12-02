module Chem::VASP::Chgcar
  @[IO::FileType(Spatial::Grid, format: Chgcar, names: %w(CHGCAR*))]
  class Reader
    include IO::Reader(Spatial::Grid)
    include Spatial::Grid::Reader
    include GridReader

    def read : Spatial::Grid
      check_open
      check_eof skip_lines: false
      info = self.info
      volume = info.bounds.volume
      read_array info, &./(volume)
    end
  end

  @[IO::FileType(format: Chgcar, names: %w(CHGCAR*))]
  class Writer < IO::Writer(Spatial::Grid)
    include VASP::GridWriter

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      volume = grid.volume
      write_array grid, &.*(volume)
    end
  end
end
