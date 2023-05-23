# This module provides support for reading MDL Mol files, including the
# variants V2000 and V3000.
#
# Format specification found in the [CTFile
# Formats](http://bit.ly/3WiuePn) document published by BIOVIA.
#
# NOTE: The title in the MOL file will be used as residue name if it
# contains 3-4 uppercase letters and numbers only. In such case, the
# comment line will be set as the title of the structure.
#
# WARNING: Basic support only. MDL valence model (implicit hydrogens),
# connectivity information besides bonds, stereochemistry information
# (e.g., chirality, 3D), advanced properties like Sgroup, reaction data,
# etc. are unsupported/ignored. Therefore, **hydrogens are expected to
# be defined explicitly**.
@[Chem::RegisterFormat(ext: %w(.mol))]
module Chem::Mol
  class Reader
    include FormatReader(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
    end

    # :nodoc:
    protected def initialize(@pull : PullParser, @sync_close : Bool = false)
      @io = @pull.io
    end

    private def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?
      title = @pull.line!.strip
      @pull.consume_line # skip software
      comment = @pull.consume_line.line!.strip.presence

      @pull.consume_line
      variant = @pull.at(33, 6).parse("Invalid Mol variant %{token}") do |str|
        case str.strip
        when "V2000" then V2000
        when "V3000" then V3000
        end
      end

      structure = Structure.build(
        guess_bonds: false,
        guess_names: false,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        if title.matches?(/^[A-Z0-9]{3,4}$/)
          builder.title comment || ""
          builder.residue title
        else
          builder.title title
        end
        variant.parse @pull, builder
      end

      if structure.atoms.all?(&.z.zero?) # non-3D
        path = (io = @io).is_a?(File) ? "file #{io.path}" : "content"
        Log.warn { "Detected non-3D molecule in MOL #{path}" }
      end

      structure
    end
  end

  private module V2000
    def self.parse(pull : PullParser, builder : Structure::Builder) : Nil
      n_atoms = pull.at(0, 3).int "Invalid number of atoms %{token}"
      n_bonds = pull.at(3, 3).int "Invalid number of bonds %{token}"
      pull.consume_line

      n_atoms.times { parse_atom(pull, builder) }
      n_bonds.times { parse_bond(pull, builder) }
      parse_property_block(pull, builder)
    end

    def self.parse_atom(pull : PullParser, builder : Structure::Builder) : Nil
      x = pull.at(0, 10).float "Invalid X coordinate %{token}"
      y = pull.at(10, 10).float "Invalid Y coordinate %{token}"
      z = pull.at(20, 10).float "Invalid Z coordinate %{token}"
      pos = Spatial::Vec3.new(x, y, z)
      ele = pull.at(31, 3).parse("Invalid element %{token}") do |str|
        PeriodicTable[str.strip]?
      end
      mass = ele.mass + pull.at?(34, 2)
        .parse_if_present("Invalid mass difference %{token}", default: 0, &.to_i?)
      chg = pull.at?(36, 3)
        .parse_if_present("Invalid formal charge %{token}", default: 0) do |str|
          parse_formal_charge str
        end
      builder.atom ele, pos, formal_charge: chg, mass: mass
      pull.consume_line
    end

    def self.parse_bond(pull : PullParser, builder : Structure::Builder) : Nil
      i = pull.at(0, 3).int("Invalid atom index %{token}")
      j = pull.at(3, 3).int("Invalid atom index %{token}")
      pull.at(6, 3).parse("Invalid bond type %{token}") do |str|
        case bond_type = str.strip
        when "1", "2", "3"
          builder.bond i, j, BondOrder.from_value(bond_type.to_i)
        when "4"
          builder.bond i, j, aromatic: true
        end
      end
      pull.consume_line
    end

    def self.parse_formal_charge(str) : Int32?
      case str.strip
      when "0" then 0
      when "3" then 1
      when "2" then 2
      when "1" then 3
      when "5" then -1
      when "6" then -2
      when "7" then -3
      end
    end

    def self.parse_property_block(pull : PullParser, builder : Structure::Builder) : Nil
      pull.each_line do
        next unless pull.at?(0, 3).str? == "M  "

        property_name = pull.at?(3, 3).str?
        break if property_name == "END"
        next unless property_name.in?("CHG", "ISO")

        n_entries = pull.at(6, 3).int "Invalid number of entries"
        pull.error("Number of entries expected within 1 to 8") unless n_entries.in?(1..8)
        n_entries.times do |i|
          col = 9 + i * 8
          atom_i = pull.at(col, 4).int "Invalid atom index"
          atom = builder.atom?(atom_i) || pull.error("Atom index #{atom_i} out of range")
          pull.at(col + 4, 4)
          case property_name
          when "CHG"
            atom.formal_charge = pull.int "Invalid formal charge %{token}"
          when "ISO"
            atom.mass = pull.float "Invalid isotope mass %{token}"
          end
        end
      end
    end
  end

  private module V3000
    def self.check_block_close(pull : PullParser, name : String) : Nil
      check_entry pull, {"END", name}, "Expected END #{name} to close #{name} block"
      pull.consume_line
    end

    def self.check_entry(
      pull : PullParser,
      tokens : Tuple,
      message : String = "Expected #{name} entry at %{loc_with_file}"
    ) : Nil
      check_entry_tag(pull)
      if tokens.map { pull.next_s? } != tokens
        pull.rewind_line
        pull.error(message)
      end
    end

    def self.check_entry_tag(
      pull : PullParser,
      message : String = "Invalid V3000 entry at %{loc_with_file}"
    ) : Nil
      if {pull.next_s?, pull.next_s?} != {"M", "V30"}
        pull.rewind_line
        pull.error(message)
      end
    end

    def self.next_block(pull : PullParser) : String?
      pull.each_line do
        case {pull.next_s?, pull.next_s?}
        when {"M", "V30"}
          return pull.next_s.tap { pull.consume_line } if pull.next_s == "BEGIN"
        when {"M", "END"}
          pull.consume_line
          break
        else # line should not be consumed
          pull.rewind_line
          break
        end
      end
    end

    def self.parse(pull : PullParser, builder : Structure::Builder) : Nil
      pull.consume_line # skips V2000 compatibility line
      n_atoms = n_bonds = 0
      while name = next_block(pull)
        case name
        when "CTAB"
          check_entry(pull, {"COUNTS"}, "Expected COUNTS entry after BEGIN CTAB")
          n_atoms = pull.next_i "Invalid number of atoms %{token}"
          n_bonds = pull.next_i "Invalid number of bonds %{token}"
          pull.consume_line
        when "ATOM"
          n_atoms.times { parse_atom(pull, builder) }
          check_block_close pull, "ATOM"
        when "BOND"
          n_bonds.times { parse_bond(pull, builder) }
          check_block_close pull, "BOND"
        end
      end
    end

    def self.parse_atom(pull : PullParser, builder : Structure::Builder) : Nil
      check_entry_tag(pull)
      serial = pull.next_i "Invalid atom serial %{token}"
      ele = pull.parse_next("Invalid element %{token}") do |str|
        PeriodicTable[str]?
      end
      x = pull.next_f "Invalid X coordinate %{token}"
      y = pull.next_f "Invalid Y coordinate %{token}"
      z = pull.next_f "Invalid Z coordinate %{token}"
      pos = Spatial::Vec3.new(x, y, z)
      pull.consume_token # skip aamap

      chg = 0
      mass = ele.mass
      while str = pull.next_s?
        name, _, str = str.partition("=")
        case name
        when "CHG"
          chg = str.to_i? || pull.error("Invalid formal charge %{token}")
        when "MASS"
          mass = str.to_f? || pull.error("Invalid isotope mass %{token}")
        end
      end

      builder.atom(ele, pos, formal_charge: chg, mass: mass)
      pull.consume_line
    end

    def self.parse_bond(pull : PullParser, builder : Structure::Builder) : Nil
      check_entry_tag(pull)
      pull.consume_token # ignore index

      aromatic = false
      bond_order = pull.parse_next("Invalid bond type %{token}") do |str|
        case bond_type = str
        when "1", "2", "3"
          BondOrder.from_value(bond_type.to_i)
        when "4"
          aromatic = true
          BondOrder::Single
        end
      end

      i = pull.next_i("Invalid atom index %{token}")
      j = pull.next_i("Invalid atom index %{token}")
      builder.bond i, j, bond_order, aromatic: aromatic
      pull.consume_line
    end
  end
end
