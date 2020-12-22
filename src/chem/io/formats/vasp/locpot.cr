@[Chem::IO::FileType(names: %w(LOCPOT*))]
module Chem::VASP::Locpot
  class Reader
    include IO::Reader(Spatial::Grid)
    include IO::TextReader(Spatial::Grid)
    include Spatial::Grid::Reader
    include GridReader

    def read : Spatial::Grid
      check_open
      check_eof skip_lines: false
      info = self.info
      read_array info, &.itself
    end
  end

  class Writer
    include IO::Writer(Spatial::Grid)
    include GridWriter

    needs structure : Structure

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
