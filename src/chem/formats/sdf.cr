@[Chem::RegisterFormat(ext: %w(.sdf), module_api: true)]
module Chem::SDF
  # Yields each structure in *io*.
  def self.each(io : IO | Path | String, & : Structure ->) : Nil
    Reader.open(io) do |reader|
      reader.each do |struc|
        yield struc
      end
    end
  end

  # Returns the first structure from *io*.
  # Use `read_all` or `each` for multiple.
  def self.read(io : IO | Path | String) : Structure
    Reader.open(io) do |reader|
      reader.read_entry
    end
  end

  # Returns all structures in *io*.
  def self.read_all(io : IO | Path | String) : Array(Structure)
    Reader.open(io) do |reader|
      ary = [] of Structure
      reader.each { |struc| ary << struc }
      ary
    end
  end

  # Writes one or more structures to *io*.
  #
  # The CTAB format is specified via *variant*: V2000 (legacy) or V3000.
  def self.write(
    io : IO | Path | String,
    obj : Structure,
    variant : Chem::Mol::Variant = :v2000,
  ) : Nil
    Writer.open(io, variant: variant) do |writer|
      writer << obj
    end
  end

  # :ditto:
  def self.write(
    io : IO | Path | String,
    objs : Enumerable(Structure),
    variant : Chem::Mol::Variant = :v2000,
  ) : Nil
    Writer.open(io, variant: variant) do |writer|
      objs.each { |struc| writer << struc }
    end
  end

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
      @sync_close : Bool = false,
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
