module Chem::VASP::Locpot
  @[IO::FileType(format: Locpot, names: %w(LOCPOT*))]
  class Parser < Spatial::Grid::Parser
    include IO::AsciiParser
    include GridParser

    def parse : Spatial::Grid
      info = self.info
      read_array info, &.itself
    end
  end

  @[IO::FileType(format: Locpot, names: %w(LOCPOT*))]
  class Writer < IO::Writer(Spatial::Grid)
    include GridWriter

    def write(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.lattice) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
