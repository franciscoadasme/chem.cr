module Chem::VASP::Chgcar
  @[RegisterFormat(format: Chgcar, names: %w(CHGCAR*))]
  class Reader < Spatial::Grid::Reader
    include GridReader

    def read_entry : Spatial::Grid
      info = self.info
      volume = info.bounds.volume
      read_array info, &./(volume)
    end
  end

  @[RegisterFormat(format: Chgcar, names: %w(CHGCAR*))]
  class Writer < FormatWriter(Spatial::Grid)
    include VASP::GridWriter

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      volume = grid.volume
      write_array grid, &.*(volume)
    end
  end
end