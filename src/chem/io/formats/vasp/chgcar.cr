module Chem::VASP::Chgcar
  @[IO::FileType(format: Chgcar, ext: [:chgcar])]
  class Parser < IO::Parser(Spatial::Grid)
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
      write_header
      volume = grid.volume
      write_array grid, &.*(volume)
    end
  end
end
