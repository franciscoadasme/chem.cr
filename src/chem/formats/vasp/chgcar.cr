require "./utils"

@[Chem::RegisterFormat(names: %w(CHGCAR*))]
module Chem::VASP::Chgcar
  class Reader
    include FormatReader(Spatial::Grid)
    include FormatReader::Headed(Spatial::Grid::Info)
    include FormatReader::Attached(Structure)
    include GridReader

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Spatial::Grid
      info = read_header
      volume = info.bounds.volume
      read_array info, &./(volume)
    end
  end

  class Writer
    include FormatWriter(Spatial::Grid)
    include VASP::GridWriter

    protected def encode_entry(obj : Spatial::Grid) : Nil
      incompatible_expcetion if (lat = @structure.cell) && lat.size != obj.bounds.size
      write_header
      volume = obj.volume
      write_array obj, &.*(volume)
    end
  end
end
