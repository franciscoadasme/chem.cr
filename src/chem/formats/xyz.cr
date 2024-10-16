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

      n_atoms = @pull.next_i

      @pull.consume_line
      ext_parser = ConfigurationParser.new(@pull)
      ext_parser.parse

      structure = Structure.build(
        guess_bonds: @guess_bonds,
        guess_names: @guess_names,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        ext_parser.cell.try { |cell| builder.cell cell }

        n_atoms.times do
          constraint = nil
          chain = resname = resid = name = number = typename = mass = vdw_radius = nil
          ele = PeriodicTable::C
          pos = Spatial::Vec3.zero
          formal_charge = 0
          partial_charge = temperature_factor = 0.0
          metadata = Metadata.new
          occupancy = 1.0

          @pull.consume_line
          ext_parser.fields.each do |field|
            case field.name
            when "species"
              @pull.consume_token
              ele = PeriodicTable[@pull.int? || @pull.str]? ||
                    @pull.error("Unknown element")
            when "pos"
              pos = Spatial::Vec3.new @pull.next_f, @pull.next_f, @pull.next_f
            when "chain"
              chain = @pull.consume_token.expect(/^[a-zA-Z0-9]$/).char
            when "constraint"
              case {@pull.next_bool, @pull.next_bool, @pull.next_bool}
              when {true, true, true}    then constraint = Spatial::Direction::XYZ
              when {false, true, true}   then constraint = Spatial::Direction::YZ
              when {true, false, true}   then constraint = Spatial::Direction::XZ
              when {true, true, false}   then constraint = Spatial::Direction::XY
              when {false, false, true}  then constraint = Spatial::Direction::Z
              when {false, true, false}  then constraint = Spatial::Direction::Y
              when {true, false, false}  then constraint = Spatial::Direction::X
              when {false, false, false} then constraint = nil
              end
            when "charge"
              if field.type == Int32
                formal_charge = @pull.next_i
              else
                partial_charge = @pull.next_f
              end
            when "formal_charge"
              formal_charge = @pull.next_i
            when "mass"
              mass = @pull.next_f
            when "name"
              name = @pull.next_s
            when "occupancy"
              occupancy = @pull.next_f
            when "partial_charge"
              partial_charge = @pull.next_f
            when "resid"
              resid = @pull.next_i
            when "resname"
              resname = @pull.next_s
            when "number"
              number = @pull.next_i
            when "temperature_factor", "bfactor"
              temperature_factor = @pull.next_f
            when "typename"
              typename = @pull.next_s
            when "vdw_radius"
              vdw_radius = @pull.next_f
            else
              value = if field.cols > 1
                        (0...field.cols).map { @pull.consume_token.parse(field.type) }
                      else
                        @pull.consume_token.parse(field.type)
                      end
              metadata[field.name] = value
            end
          end

          chain.try { |ch| builder.chain ch }
          if i = resid
            builder.residue resname || "UNK", i
          elsif resname && builder.current_residue.try(&.name) != resname
            builder.residue resname
          end

          atom = builder.atom ele, pos
          {% for name in %w(constraint formal_charge mass name occupancy
                           partial_charge number temperature_factor typename
                           vdw_radius) %}
            atom.{{name.id}} = {{name.id}} if {{name.id}}
          {% end %}
          atom.metadata.merge! metadata
        end
        @pull.consume_line
      end

      ext_parser.title.try { |title| structure.title = title }
      structure.metadata.merge! ext_parser.metadata

      structure
    end

    def skip_entry : Nil
      return if @pull.eof?
      n_atoms = @pull.next_i
      (n_atoms + 2).times { @pull.consume_line }
    end
  end

  class Writer
    include FormatWriter(AtomContainer)
    include FormatWriter::MultiEntry(AtomContainer)

    private TYPE_CHAR_MAP = {Bool => 'L', Int32 => 'I', Float64 => 'R', String => 'S'}

    def initialize(@io : IO,
                   @extended : Bool = false,
                   @fields : Array(String) = [] of String,
                   @total_entries : Int32? = nil,
                   @sync_close : Bool = false)
    end

    protected def encode_entry(obj : AtomContainer) : Nil
      atoms = obj.is_a?(AtomView) ? obj : obj.atoms

      @io.puts atoms.size
      if obj.is_a?(Structure)
        if @extended
          @fields = atoms.first.metadata.keys if @fields.empty?
          write_extended_config(obj)
        else
          @io.puts obj.title.gsub(/ *\n */, ' ')
        end
      else
        @io.puts
      end

      atoms.each do |atom|
        @io.printf "%-2s %8.3f %8.3f %8.3f", atom.element.symbol, atom.x, atom.y, atom.z
        @fields.each do |name|
          @io << ' '
          case name
          when "chain"
            @io << atom.chain.id
          when "constraint"
            {Spatial::Direction::X, Spatial::Direction::Y, Spatial::Direction::Z}
              .each_with_index do |axis, i|
                flag = atom.constraint.try(&.includes?(axis)) || false
                @io << ' ' if i > 0
                @io << (flag ? 'T' : 'F')
              end
          when "formal_charge", "charge"
            @io.printf "%2d", atom.formal_charge
          when "mass"
            @io.printf "%8.4f", atom.mass
          when "name"
            @io.printf "%-4s", atom.name
          when "occupancy"
            @io.print "%6.2f", atom.occupancy
          when "partial_charge"
            @io.printf "%8.4f", atom.partial_charge
          when "resid"
            @io.printf "%4d", atom.residue.number
          when "resname"
            @io.printf "%-4s", atom.residue.name
          when "number"
            @io.printf "%5d", atom.number
          when "temperature_factor", "bfactor"
            @io.printf "%6.2f", atom.temperature_factor
          when "typename"
            @io.printf "%4s", atom.typename
          when "vdw_radius"
            @io.printf "%8.3f", atom.vdw_radius
          else
            value = atom.metadata[name]? ||
                    raise "Property #{name} not found in metadata of #{atom}"
            (value.as_a? || {value}).each do |ele|
              case type = ele.raw.class
              when Bool.class    then @io << (ele.raw ? 'T' : 'F')
              when Int32.class   then @io.printf "%5d", ele.raw
              when Float64.class then @io.printf "%8g", ele.raw
              when String.class
                if ele.as_s.strip.count(&.whitespace?) > 0
                  raise "Cannot write string with whitespace in extended XYZ"
                end
                @io << ele.as_s.strip
              else
                raise "Cannot write #{type} in extended XYZ"
              end
            end
          end
        end
        @io.puts
      end
    end

    private def write_atom_properties(metadata : Metadata) : Nil
      @io << "species:S:1" << ':' << "pos:R:3"
      @fields.each do |name|
        @io << ':' << name << ':'
        case name
        when "chain"                         then @io << "S:1"
        when "constraint"                    then @io << "L:3"
        when "formal_charge", "charge"       then @io << "I:1"
        when "mass"                          then @io << "F:1"
        when "name"                          then @io << "S:1"
        when "occupancy"                     then @io << "F:1"
        when "partial_charge"                then @io << "F:1"
        when "resid"                         then @io << "I:1"
        when "resname"                       then @io << "S:1"
        when "number"                        then @io << "I:1"
        when "temperature_factor", "bfactor" then @io << "F:1"
        when "typename"                      then @io << "S:1"
        when "vdw_radius"                    then @io << "F:1"
        else
          if value = metadata[name]?
            if arr = value.as_a?
              raise ArgumentError.new("Nested arrays are not supported") if arr[0].as_a?
              type = arr[0].raw.class
              cols = arr.size
            else
              type = value.raw.class
              cols = 1
            end

            type = TYPE_CHAR_MAP[type]? || raise "Cannot write #{type} in extended XYZ"
            @io << type << ':' << cols
          else
            raise ArgumentError.new("Property #{name} not found in atom metadata")
          end
        end
      end
    end

    private def write_extended_config(structure : Structure) : Nil
      @io << "Title="
      structure.title.gsub(/ *\n */, ' ').inspect @io
      @io << ' ' << "Properties="
      write_atom_properties structure.atoms.first.metadata
      if cell = structure.cell?
        @io << ' ' << "Lattice=" << '['
        cell.basisvec.each_with_index do |(x, y, z), i|
          @io << ", " if i > 0
          @io << '['
          {x, y, z}.join(@io, ", ") { |i, io| io << i }
          @io << ']'
        end
        @io << ']'
      end
      structure.metadata.each do |key, value|
        @io << ' ' << key.camelcase << '='
        value.raw.inspect @io
      end
      @io.puts
    end
  end

  private class ConfigurationParser
    record Field,
      name : String,
      type : Int32.class | Float64.class | String.class | Bool.class,
      cols : Int32 = 1

    TYPE_CHARS  = {'S' => String, 'I' => Int32, 'R' => Float64, 'L' => Bool}
    FIELD_SPECS = {
      "chain"      => "chain:S:1",
      "charge"     => %w(charge:I:1 charge:F:1),
      "constraint" => "constraint:L:3",
      "pos"        => "pos:R:3",
      "resid"      => "resid:I:1",
      "resname"    => "resname:S:1",
      "species"    => "species:S:1",
    }

    getter cell : Spatial::Parallelepiped?
    getter fields = [] of Field
    getter metadata = Metadata.new
    getter title = ""

    def initialize(@pull : PullParser)
    end

    def consume_token(delim : String = " \t=") : Nil
      @pull.skip_whitespace
      if (quote = @pull.peek) && quote.in?('"', "'")
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
    end

    def make_cell(value : Metadata::Any) : Spatial::Parallelepiped
      if vecs = value.as_2a?(Float64)
        if vecs.size == 3 && vecs.all?(&.size.==(3))
          i, j, k = vecs
          i = Spatial::Vec3[i[0], i[1], i[2]]
          j = Spatial::Vec3[j[0], j[1], j[2]]
          k = Spatial::Vec3[k[0], k[1], k[2]]
          Spatial::Parallelepiped.new i, j, k
        else
          @pull.error "Invalid cell basis vectors"
        end
      elsif params = value.as_a?(Float64)
        case params.size
        when 6
          size = {params[0], params[1], params[2]}
          angles = {params[3], params[4], params[5]}
          Spatial::Parallelepiped.new size, angles
        when 9
          i = Spatial::Vec3[params[0], params[1], params[2]]
          j = Spatial::Vec3[params[3], params[4], params[5]]
          k = Spatial::Vec3[params[6], params[7], params[8]]
          Spatial::Parallelepiped.new i, j, k
        else
          @pull.error "Invalid cell parameters"
        end
      elsif str = value.as_s?
        params = str.split.map do |x|
          x.to_f? || @pull.error "Invalid cell value #{x.inspect}"
        end
        make_cell Metadata::Any.new(params)
      else
        @pull.error "Invalid cell parameters"
      end
    end

    def parse : Nil
      if @pull.line!.includes?("Properties=")
        until @pull.skip_whitespace.eol?
          consume_token
          name = @pull.str.underscore
          if @pull.skip_whitespace.peek == '='
            @pull.consume(1).expect('=').skip_whitespace
            if name == "properties"
              parse_atom_field_spec
              next
            elsif @pull.peek.in?('{', '[')
              value = parse_array
            else
              consume_token
              value = parse_value
            end
          else # properties by themselves are implicitly set to true
            value = true
          end

          case name
          when "lattice"
            @cell = make_cell Metadata::Any.new(value)
          when "title"
            @title = value.as(String)
          else
            @metadata[name.underscore] = value
          end
        end
      else
        @fields << Field.new("species", String) << Field.new("pos", Float64, 3)
        @title = @pull.line!.strip
      end
    end

    def parse_array : Array(Metadata::ValueType) | Array(Array(Metadata::ValueType))
      open_array_delim = @pull.consume(1).char
      new_style = open_array_delim == '['
      close_array_delim = new_style ? ']' : '}'
      value_delim = " \t#{close_array_delim}#{',' if new_style}"

      case @pull.skip_whitespace.peek
      when '['
        if new_style
          arrays = parse_arrays
          @pull.consume(1).expect ']', "Unterminated array"
          return arrays
        else
          @pull.error "Invalid nested array (use [[...]] syntax)"
        end
      when '{'
        @pull.error "Invalid nested array (use [[...]] syntax)"
      end

      Array(Metadata::ValueType).new.tap do |arr|
        loop do
          consume_token value_delim
          arr << parse_value
          break if @pull.skip_whitespace.peek.in?(nil, close_array_delim)
          @pull.consume(1).expect(',') if new_style
        end
        @pull.skip_whitespace.consume(1).expect(close_array_delim, "Unterminated array")
      end
    end

    def parse_arrays : Array(Array(Metadata::ValueType))
      Array(Array(Metadata::ValueType)).new.tap do |arr|
        loop do
          case @pull.skip_whitespace.peek
          when ']'
            break
          when '['
            arr << parse_array.as(Array(Metadata::ValueType))
          when ','
            @pull.consume(1)
          else
            @pull.error "Unexpected token #{@pull.str?.inspect}"
          end
        end
      end
    end

    def parse_atom_field_spec : Nil
      @pull.consume(1) if @pull.peek == '"'
      while (char = @pull.peek) && !char.in?(' ', '\t', '"')
        consume_token(delim: ":\"")
        name = @pull.str("Expected column name")

        @pull.consume(1).expect(':')

        @pull.consume(1).expect(TYPE_CHARS.keys)
        type_char = @pull.char
        type = TYPE_CHARS[type_char]

        @pull.consume(1).expect(':')

        consume_token(delim: ":\" ")
        cols = @pull.int("Invalid number of columns")

        # check field spec if predefined
        FIELD_SPECS[name]?.try do |expected|
          actual = "#{name}:#{type_char}:#{cols}"
          case expected
          in Array
            unless actual.in?(expected)
              expected = expected.sentence(
                pair_separator: " or ",
                tail_separator: ", or ")
              @pull.error("Expected #{expected}, got #{actual}")
            end
          in String
            @pull.error("Expected #{expected}, got #{actual}") unless actual == expected
          end
        end

        @fields << Field.new(name, type, cols)
        @pull.consume(1) if @pull.peek == ':'
      end
      @pull.consume(1) if @pull.peek == '"'

      field_names = @fields.map(&.name)
      unless "species".in?(field_names) && "pos".in?(field_names)
        @pull.error "Properties do not contain 'species:S:1' nor 'pos:R:3'"
      end
    end

    def parse_value : Int32 | Float64 | String | Bool
      @pull.int?.try { |int| return int }
      @pull.float?.try { |float| return float }
      @pull.bool?.try { |bool| return bool }
      @pull.str.strip("\"'")
    end
  end
end
