@[Chem::RegisterFormat(ext: %w(.mae .maegz))]
module Chem::Maestro
  BLOCK_BEGINNING     = '{'
  BLOCK_HEADER_REGEX  = /^ *([fc](_[a-zA-Z0-9]+)+) *#{BLOCK_BEGINNING} *$/
  PROPERTY_NAME_REGEX = /^[birs]_[a-zA-Z0-9]+_.+$/
  BLOCK_END           = '}'
  DELIMITER           = ":::"
  EMPTY_FIELD         = "<>"

  class Reader
    include FormatReader(Structure)

    # include FormatReader::MultiEntry(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    protected def decode_entry : Structure
      next_block "f_m_ct"
      @pull.consume_line

      structure = Structure.new

      read_properties.each do |name|
        structure.metadata[name] = read_value_for(name)
        @pull.consume_line
      end

      if "r_pdb_PDB_CRYST1_a".in?(structure.metadata)
        {% begin %}
          {% for name in %w(a b c alpha beta gamma) %}
            {{name.id}} = structure.metadata["r_pdb_PDB_CRYST1_{{name.id}}"].as_f
          {% end %}
          structure.cell = Spatial::Parallelepiped.new({a, b, c}, {alpha, beta, gamma})
        {% end %}
      end

      @pull.each_line { |line| break if @pull.next_s =~ /m_atom\[ *(\d+) *\]/ }
      size = $~[1]?.try(&.to_i?) || @pull.error("Invalid atom section header")
      @pull.consume_line
      properties = read_properties
      size.times do
        serial = @pull.next_i
        x = y = z = partial_charge = bfactor = occupancy = 0.0
        formal_charge = 0
        chid = resnum = name = resname = inscode = nil
        element = PeriodicTable::C
        metadata = Metadata.new
        color = Color::WHITE
        sec = Protein::SecondaryStructure::None
        properties.each do |name|
          case name
          when "r_m_x_coord"          then x = read_value(Float64)
          when "r_m_y_coord"          then y = read_value(Float64)
          when "r_m_z_coord"          then z = read_value(Float64)
          when "s_m_pdb_atom_name"    then name = read_value(String).strip.presence
          when "i_m_residue_number"   then resnum = read_value(Int32)
          when "s_m_pdb_residue_name" then resname = read_value(String).strip.presence
          when "s_m_insertion_code"   then inscode = read_value(String).strip[0]?
          when "s_m_chain_name"       then chid = read_value(String).strip[0]?
          when "i_m_formal_charge"    then formal_charge = read_value(Int32)
          when "r_m_charge1"          then partial_charge = read_value(Float64)
          when "r_m_charge2"          then partial_charge = read_value(Float64)
          when "s_m_color_rgb"        then color = Color.from_hex(read_value(String))
          when "r_m_pdb_occupancy"    then occupancy = read_value(Float64)
          when "r_m_pdb_tfactor"      then bfactor = read_value(Float64)
          when "i_pdb_PDB_serial"     then serial = read_value(Int32)
          when "s_m_atom_name"
            read_value(String).strip.presence.try { |x| name ||= x }
          when "i_m_secondary_structure"
            ec = Protein::SecondaryStructure.from_value read_value(Int32)
          when "i_m_color"
            color = IndexedColor.from_value(read_value(Int32)).to_rgb
          when "i_m_atomic_number"
            element = PeriodicTable[read_value(Int32)]? ||
                      @pull.error "Invalid atomic number %{token}"
          else
            metadata[name] = read_value_for(name)
          end
        end

        if chid
          chain = structure.dig?(chid) || Chain.new(structure, chid)
        else
          chain = structure.chains[0]? || Chain.new(structure, 'A')
        end

        residue = resnum.try { |x| chain.dig?(x || 1, inscode) } ||
                  Residue.new(chain, resnum || 1, inscode, resname || "UNK")
        residue.sec = sec
        atom = Atom.new residue, serial, element, name || "XXX", Spatial::Vec3[x, y, z]
        atom.partial_charge = partial_charge
        atom.temperature_factor = bfactor
        atom.occupancy = occupancy
        atom.formal_charge = formal_charge
        atom.metadata.merge! metadata
        # atom.color = color

        @pull.consume_line
      end

      structure
    end

    private def block_name : String?
      if @pull.peek == BLOCK_BEGINNING # unnamed block
        ""
      elsif @pull.line =~ BLOCK_HEADER_REGEX
        $~[1]
      else
        nil
      end
    end

    private def next_block : String?
      @pull.skip_blank_lines
      if name = block_name
        name
      else # in a middle of a block
        skip_block
        @pull.skip_blank_lines
        block_name
      end
    end

    private def next_block(name : String) : Nil
      until @pull.eof? || next_block == name
        skip_block
      end
      raise IO::EOFError.new if @pull.eof?
    end

    private def read_properties : Array(String)
      Array(String).new.tap do |properties|
        @pull.each_line do
          str = @pull.next_s.delete('\\')
          break if str == DELIMITER
          next if str == "#"
          if str =~ PROPERTY_NAME_REGEX
            properties << str
          else
            @pull.error "Invalid property '%{token}'. " \
                        "Must follow format '(b|i|r|s)_<author>_<name>'"
          end
        end
        @pull.consume_line
      end
    end

    private def read_value_for(name : String) : Bool | Int32 | Float64 | String
      type = case name[0]
             when 'b' then Bool
             when 'i' then Int32
             when 'r' then Float64
             when 's' then String
             else          raise "BUG: unreachable"
             end
      read_value type
    end

    private def read_value(type : Bool.class) : Bool
      @pull.parse_next("Invalid boolean") do |str|
        case str
        when "0", EMPTY_FIELD then false
        when "1"              then true
        end
      end
    end

    private def read_value(type : Float64.class) : Float64
      @pull.consume_token
      @pull.token == EMPTY_FIELD.to_slice ? 0.0 : @pull.float
    end

    private def read_value(type : Int32.class) : Int32
      @pull.consume_token
      @pull.token == EMPTY_FIELD.to_slice ? 0 : @pull.int
    end

    private def read_value(type : String.class) : String
      @pull.skip_whitespace
      if @pull.peek == '"'
        quote_count = 2
        escaped = false
        @pull.consume do |char|
          should_consume_char = quote_count > 0
          case char
          when '\\'
            escaped = true
          when '"'
            quote_count -= 1 unless escaped
            escaped = false
          else
            escaped = false
          end
          should_consume_char
        end
        @pull.str.strip('"').strip.unescape
      else
        value = @pull.next_s
        value = "" if value == EMPTY_FIELD
        value
      end
    end

    private def skip_block : Nil
      @pull.consume_line
      block_level = 1
      @pull.each_line do |line|
        case line.rstrip[-1]?
        when BLOCK_BEGINNING then block_level += 1
        when BLOCK_END       then block_level -= 1
        end
        break if block_level == 0
      end
      @pull.error "Unclosed block" unless block_level == 0
      @pull.consume_line
    end
  end

  enum IndexedColor
    Black       =  1
    Gray        =  2
    DarkBlue    =  3
    Blue        =  4
    LightBlue   =  5
    Aquamarine  =  6
    Turquoise   =  7
    SpringGreen =  8
    DarkGreen   =  9
    Green       = 10
    LimeGreen   = 11
    YellowGreen = 12
    Yellow      = 13
    Orange      = 14
    Maroon      = 15
    Red         = 16
    Pink        = 17
    Plum        = 18
    Purple      = 19
    BluePurple  = 20
    White       = 21
    Brown       = 22
    Coral       = 23
    DimGray     = 24
    Goldenrod   = 25
    HotPink     = 26
    Olive       = 27
    Peru        = 28
    Sienna      = 29
    SteelBlue   = 30
    Thistle     = 31
    Wheat       = 32
    Blue1       = 33
    Blue2       = 34
    Blue3       = 35
    Blue4       = 36
    Blue5       = 37
    Blue6       = 38
    Blue7       = 39
    Blue8       = 40
    Blue9       = 41
    Blue10      = 42
    Blue11      = 43
    Blue12      = 44
    Blue13      = 45
    Blue14      = 46
    Blue15      = 47
    Blue16      = 48
    Blue17      = 49
    Blue18      = 50
    Blue19      = 51
    Blue20      = 52
    Blue21      = 53
    Blue22      = 54
    Blue23      = 55
    Blue24      = 56
    Blue25      = 57
    Blue26      = 58
    Blue27      = 59
    Blue28      = 60
    Blue29      = 61
    Blue30      = 62
    Blue31      = 63
    Blue32      = 64
    Red1        = 65
    Red2        = 66
    Red3        = 67
    Red4        = 68
    Red5        = 69
    Red6        = 70
    Red7        = 71
    Red8        = 72
    Red9        = 73
    Red10       = 74
    Red11       = 75
    Red12       = 76
    Red13       = 77
    Red14       = 78
    Red15       = 79
    Red16       = 80
    Red17       = 81
    Red18       = 82
    Red19       = 83
    Red20       = 84
    Red21       = 85
    Red22       = 86
    Red23       = 87
    Red24       = 88
    Red25       = 89
    Red26       = 90
    Red27       = 91
    Red28       = 92
    Red29       = 93
    Red30       = 94
    Red31       = 95
    Red32       = 96

    def to_rgb
      case self
      in Black       then Color.new(0, 0, 0)
      in Gray        then Color.new(160, 160, 160)
      in DarkBlue    then Color.new(0, 0, 180)
      in Blue        then Color.new(30, 30, 225)
      in LightBlue   then Color.new(100, 100, 225)
      in Aquamarine  then Color.new(112, 219, 147)
      in Turquoise   then Color.new(173, 234, 234)
      in SpringGreen then Color.new(0, 255, 127)
      in DarkGreen   then Color.new(0, 100, 0)
      in Green       then Color.new(30, 225, 30)
      in LimeGreen   then Color.new(50, 204, 50)
      in YellowGreen then Color.new(153, 204, 30)
      in Yellow      then Color.new(225, 225, 30)
      in Orange      then Color.new(234, 130, 50)
      in Maroon      then Color.new(142, 35, 107)
      in Red         then Color.new(225, 30, 30)
      in Pink        then Color.new(255, 152, 163)
      in Plum        then Color.new(234, 173, 234)
      in Purple      then Color.new(225, 30, 225)
      in BluePurple  then Color.new(159, 95, 159)
      in White       then Color.new(255, 255, 255)
      in Brown       then Color.new(165, 42, 42)
      in Coral       then Color.new(225, 127, 80)
      in DimGray     then Color.new(105, 105, 105)
      in Goldenrod   then Color.new(225, 193, 37)
      in HotPink     then Color.new(225, 105, 180)
      in Olive       then Color.new(107, 142, 35)
      in Peru        then Color.new(205, 133, 63)
      in Sienna      then Color.new(160, 82, 45)
      in SteelBlue   then Color.new(70, 130, 180)
      in Thistle     then Color.new(216, 191, 216)
      in Wheat       then Color.new(245, 222, 179)
      in Blue1       then Color.new(7, 7, 255)
      in Blue2       then Color.new(15, 15, 255)
      in Blue3       then Color.new(23, 23, 255)
      in Blue4       then Color.new(31, 31, 255)
      in Blue5       then Color.new(39, 39, 255)
      in Blue6       then Color.new(47, 47, 255)
      in Blue7       then Color.new(55, 55, 255)
      in Blue8       then Color.new(63, 63, 255)
      in Blue9       then Color.new(71, 71, 255)
      in Blue10      then Color.new(79, 79, 255)
      in Blue11      then Color.new(87, 87, 255)
      in Blue12      then Color.new(95, 95, 255)
      in Blue13      then Color.new(103, 103, 255)
      in Blue14      then Color.new(111, 111, 255)
      in Blue15      then Color.new(119, 119, 255)
      in Blue16      then Color.new(127, 127, 255)
      in Blue17      then Color.new(135, 135, 255)
      in Blue18      then Color.new(143, 143, 255)
      in Blue19      then Color.new(151, 151, 255)
      in Blue20      then Color.new(159, 159, 255)
      in Blue21      then Color.new(167, 167, 255)
      in Blue22      then Color.new(175, 175, 255)
      in Blue23      then Color.new(183, 183, 255)
      in Blue24      then Color.new(191, 191, 255)
      in Blue25      then Color.new(199, 199, 255)
      in Blue26      then Color.new(207, 207, 255)
      in Blue27      then Color.new(215, 215, 255)
      in Blue28      then Color.new(223, 223, 255)
      in Blue29      then Color.new(231, 231, 255)
      in Blue30      then Color.new(239, 239, 255)
      in Blue31      then Color.new(247, 247, 255)
      in Blue32      then Color.new(255, 255, 255)
      in Red1        then Color.new(255, 7, 7)
      in Red2        then Color.new(255, 15, 15)
      in Red3        then Color.new(255, 23, 23)
      in Red4        then Color.new(255, 31, 31)
      in Red5        then Color.new(255, 39, 39)
      in Red6        then Color.new(255, 47, 47)
      in Red7        then Color.new(255, 55, 55)
      in Red8        then Color.new(255, 63, 63)
      in Red9        then Color.new(255, 71, 71)
      in Red10       then Color.new(255, 79, 79)
      in Red11       then Color.new(255, 87, 87)
      in Red12       then Color.new(255, 95, 95)
      in Red13       then Color.new(255, 103, 103)
      in Red14       then Color.new(255, 111, 111)
      in Red15       then Color.new(255, 119, 119)
      in Red16       then Color.new(255, 127, 127)
      in Red17       then Color.new(255, 135, 135)
      in Red18       then Color.new(255, 143, 143)
      in Red19       then Color.new(255, 151, 151)
      in Red20       then Color.new(255, 159, 159)
      in Red21       then Color.new(255, 167, 167)
      in Red22       then Color.new(255, 175, 175)
      in Red23       then Color.new(255, 183, 183)
      in Red24       then Color.new(255, 191, 191)
      in Red25       then Color.new(255, 199, 199)
      in Red26       then Color.new(255, 207, 207)
      in Red27       then Color.new(255, 215, 215)
      in Red28       then Color.new(255, 223, 223)
      in Red29       then Color.new(255, 231, 231)
      in Red30       then Color.new(255, 239, 239)
      in Red31       then Color.new(255, 247, 247)
      in Red32       then Color.new(255, 255, 255)
      end
    end
  end
end
