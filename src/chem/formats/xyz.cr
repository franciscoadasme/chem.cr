@[Chem::RegisterFormat(ext: %w(.xyz))]
module Chem::XYZ
  class Reader
    include FormatReader(Structure)
    include FormatReader::MultiEntry(Structure)

    def initialize(
      @io : IO,
      @guess_bonds : Bool = false,
      @guess_names : Bool = false,
      @sync_close : Bool = false
    )
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?
      Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        n_atoms = @pull.next_i
        @pull.next_line
        metadata, columns = ExtendedParser.new(@pull).parse
        builder.title columns.empty? ? @pull.line.strip : (metadata["title"].as_s || "")
        @pull.next_line
        n_atoms.times do
          @pull.consume_token
          ele = PeriodicTable[@pull.int? || @pull.str]? || @pull.error("Unknown element")
          vec = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
          builder.atom ele, vec
          @pull.next_line
        end
      end
    end

    def skip_entry : Nil
      return if @pull.eof?
      n_atoms = @pull.next_i
      (n_atoms + 2).times { @pull.next_line }
    end
  end

  private class ExtendedParser
    private record Column,
      name : String,
      type : Int32.class | Float64.class | String.class | Bool.class,
      width : Int32

    def initialize(@pull : PullParser)
    end

    def find_consume_token(delim : String = " \t=") : Bool
      @pull.skip_whitespace
      return false unless quote = @pull.peek

      if quote && quote.in?('"', "'")
        quotes = 0
        @pull.consume do |char|
          if quotes < 2
            escaped = char == '\\'
            quotes += 1 if char == quote && !escaped
            true
          else
            false
          end
        end
        @pull.error("Unterminated quoted string") unless @pull.str[-1] == quote
      else
        @pull.consume &.in?(delim).!
      end
      true
    end

    def parse : {Metadata?, Array(Column)}
      cols = [] of Column
      metadata = Metadata.new

      return {metadata, cols} unless @pull.line.includes?("Properties=")

      while find_consume_token
        name = @pull.str
        if @pull.skip_whitespace.peek == '='
          @pull.consume(1).expect('=').skip_whitespace
          if @pull.peek.in?('{', '[')
            value = parse_array
          else
            find_consume_token
            value = parse_value
          end
        else # properties by themselves are implicitly set to true
          value = true
        end
        puts "#{name} => #{value.inspect}"
      end
      {metadata, cols}
    end

    def parse_array
      open_array_delim = @pull.consume(1).char
      new_style = open_array_delim == '['
      close_array_delim = new_style ? ']' : '}'
      value_delim = " \t#{close_array_delim}#{',' if new_style}"

      if !new_style && @pull.skip_whitespace.peek.in?('{', '[')
        @pull.error "Invalid nested array (use [[...]] syntax)"
      end

      Array(Metadata::ValueType).new.tap do |array|
        loop do
          find_consume_token value_delim
          array << parse_value
          break if @pull.skip_whitespace.peek.in?(nil, close_array_delim)
          @pull.consume(1).expect(',') if new_style
        end
        @pull.skip_whitespace.consume(1).expect(close_array_delim, "Unterminated array")
      end
    end

    def parse_value : Metadata::ValueType
      @pull.int?.try { |int| return int }
      @pull.float?.try { |float| return float }

      case (str = @pull.str).downcase
      when "t", "true"
        true
      when "f", "false"
        false
      else
        str.strip("\"'")
      end
    end
  end

  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter::MultiEntry(AtomCollection)

    protected def encode_entry(obj : AtomCollection) : Nil
      @io.puts obj.n_atoms
      @io.puts obj.is_a?(Structure) ? obj.title.gsub(/ *\n */, ' ') : ""
      obj.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end
  end
end
