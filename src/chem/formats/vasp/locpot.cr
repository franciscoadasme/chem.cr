require "./utils"

@[Chem::RegisterFormat(names: %w(LOCPOT*))]
module Chem::VASP::Locpot
  class Reader
    include FormatReader(Spatial::Grid)
    include FormatReader::Headed(Spatial::Grid::Info)
    include FormatReader::Attached(Structure)
    include GridReader

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Spatial::Grid
      read_array read_header, &.itself
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)
    include GridWriter

    protected def encode_entry(grid : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.cell) && lat.size != grid.bounds.size
      write_header
      write_array(grid, &.itself)
    end
  end
end
