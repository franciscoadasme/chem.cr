module Chem::VASP::Locpot
  @[IO::FileType(Spatial::Grid, format: Locpot, names: %w(LOCPOT*))]
  class Reader < Spatial::Grid::Reader
    include IO::Reader(Spatial::Grid)
    include GridReader

    def initialize(io : ::IO, @sync_close : Bool = false)
      @io = IO::TextIO.new io
    end

    def read : Spatial::Grid
      check_eof skip_lines: false
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
