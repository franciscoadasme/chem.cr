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
      structure.metadata.merge! parse_metadata
      @pull.expect("$$$$").consume_line
      structure
    end

    private def parse_metadata : Metadata
      Chem::Metadata.new.tap do |metadata|
        while @pull.consume_line.next_s? == ">"
          key = @pull.expect_next(/<\w+>/).str.lchop('<').rchop('>').underscore
          value = @pull.consume_line.line.presence || @pull.error "Expected a data value for field #{key}"
          if value.size == 200 # may be split into multiple lines
            while @pull.consume_line.line.presence
              value += @pull.line || ""
            end
          elsif !@pull.consume_line.line.try(&.blank?)
            @pull.error "Expected blank line after field #{key}"
          end
          metadata[key] = value.to_i? || value.to_f? || value
        end
      end
    end

    def skip_entry : Nil
      skip_after_delimiter
    end

    private def skip_after_delimiter
      until @pull.eof? || @pull.next_s? == "$$$$"
        @pull.consume_line
      end
      @pull.consume_line
    end
  end

  class Writer
    include FormatWriter(Structure)
    include FormatWriter::MultiEntry(Structure)

    def initialize(
      @io : IO,
      @variant : Chem::Mol::Variant = :v2000,
      @total_entries : Int32? = nil,
      @sync_close : Bool = false
    )
    end

    private def encode_entry(obj : Structure) : Nil
      obj.to_mol @io, @variant
      obj.metadata.each do |key, value|
        @io.puts "> <#{key.underscore.upcase}>  (#{@entry_index + 1})"
        if str = value.as_s?
          str.scan(/.{1,200}( |$)/).each do |match|
            @io.puts match[0]
          end
        else
          @io.puts value
        end
        @io.puts
      end
      @io.puts "$$$$"
    end
  end
end
