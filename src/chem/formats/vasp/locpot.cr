require "./utils"

module Chem::VASP::Locpot
  @[RegisterFormat(format: Locpot, names: %w(LOCPOT*))]
  class Reader < Spatial::Grid::Reader
    include GridReader

    def read_entry : Spatial::Grid
      info = self.info
      read_array info, &.itself
    end
  end

  @[RegisterFormat(format: Locpot, names: %w(LOCPOT*))]
  class Writer < FormatWriter(Spatial::Grid)
    include GridWriter

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
