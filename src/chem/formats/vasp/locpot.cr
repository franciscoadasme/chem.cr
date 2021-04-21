@[Chem::FileType(names: %w(LOCPOT*))]
module Chem::VASP::Locpot
  class Reader
    include FormatReader(Spatial::Grid)
    include TextFormatReader(Spatial::Grid)
    include GridReader

    def read(type : Spatial::Grid.class) : Spatial::Grid
      check_open
      check_eof skip_lines: false
      info = read_info Spatial::Grid
      read_array info, &.itself
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)
    include GridWriter

    needs structure : Structure

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
