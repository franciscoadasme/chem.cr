@[Chem::RegisterFormat(ext: %w(.sdf))]
module Chem::SDF
  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
    end

    private def decode_entry : Structure
      structure = Mol::Reader.new(@pull).read_entry
      skip_after_delimiter
      structure
    end

    def skip_entry : Nil
      skip_after_delimiter
    end

    private def skip_after_delimiter
      until @pull.eof? || @pull.next_s? == "$$$$"
        @pull.next_line
      end
      @pull.next_line
    end
  end
end
