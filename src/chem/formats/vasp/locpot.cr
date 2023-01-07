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

    protected def encode_entry(obj : Spatial::Grid) : Nil
      incompatible_expcetion if (cell = @structure.cell?) && cell.size != obj.bounds.size
      write_header
      write_array(obj, &.itself)
    end
  end
end
