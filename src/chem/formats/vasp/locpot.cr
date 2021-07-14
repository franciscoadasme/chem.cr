require "./utils"

@[Chem::RegisterFormat(names: %w(LOCPOT*))]
module Chem::VASP::Locpot
  class Reader < Spatial::Grid::Reader
    include FormatReader::Headed(Spatial::Grid::Info)
    include GridReader

    protected def decode_entry : Spatial::Grid
      read_array read_header, &.itself
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
