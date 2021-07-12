require "./utils"

@[Chem::RegisterFormat(names: %w(LOCPOT*))]
module Chem::VASP::Locpot
  class Reader < Spatial::Grid::Reader
    include GridReader

    def read_entry : Spatial::Grid
      info = self.info
      read_array info, &.itself
    end
  end

  class Writer < FormatWriter(Spatial::Grid)
    include GridWriter

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
