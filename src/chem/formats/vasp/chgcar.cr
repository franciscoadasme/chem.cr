require "./utils"

@[Chem::RegisterFormat(names: %w(CHGCAR*))]
module Chem::VASP::Chgcar
  class Reader < Spatial::Grid::Reader
    include FormatReader::Headed(Spatial::Grid::Info)
    include GridReader

    protected def decode_entry : Spatial::Grid
      info = read_header
      volume = info.bounds.volume
      read_array info, &./(volume)
    end
  end

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
