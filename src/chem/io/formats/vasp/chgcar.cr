module Chem::VASP::Chgcar
  @[IO::FileType(format: Chgcar, ext: [:chgcar])]
  class Parser < Spatial::Grid::Parser
    include IO::AsciiParser
    include VASP::GridParser

    def parse : Spatial::Grid
      nx, ny, nz, bounds = read_header
      volume = bounds.volume
      read_array nx, ny, nz, bounds, &./(volume)
    end
  end

  @[IO::FileType(format: Chgcar, ext: [:chgcar])]
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
