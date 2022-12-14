@[Chem::RegisterFormat(ext: %w(.mol))]
module Chem::Mol
  enum Variant
    V2000
    V3000
  end

  class Reader
    include FormatReader(Structure)

    def initialize(@io : IO, @sync_close : Bool = false)
      @pull = PullParser.new @io
    end

    private def check_v3000 : Nil
      if {@pull.next_s?, @pull.next_s?} != {"M", "V30"}
        @pull.rewind_line
        @pull.error "Invalid V3000 line"
      end
    end

    private def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?
      title = @pull.line.strip
      @pull.next_line
      @pull.next_line # skip software
      @pull.next_line # skip comment line

      variant = @pull.at(33, 6).parse("Invalid Mol variant %{token}") do |str|
        Variant.parse? str.strip
      end

      Structure.build(
        guess_bonds: false,
        guess_names: false,
        source_file: (file = @io).is_a?(File) ? file.path : nil,
        use_templates: false,
      ) do |builder|
        builder.title title
        case variant
        in .v2000?
          parse_block_v2000(builder)
        in .v3000?
          @pull.next_line
          parse_block_v3000(builder)
        end
      end
    end

    private def parse_block_v2000(builder : Structure::Builder) : Nil
      n_atoms = @pull.at(0, 3).int "Invalid number of atoms %{token}"
      n_bonds = @pull.at(3, 3).int "Invalid number of bonds %{token}"
      @pull.next_line

      n_atoms.times do
        x = @pull.at(0, 10).float "Invalid X coordinate %{token}"
        y = @pull.at(10, 10).float "Invalid Y coordinate %{token}"
        z = @pull.at(20, 10).float "Invalid Z coordinate %{token}"
        pos = Spatial::Vec3.new(x, y, z)
        ele = @pull.at(31, 3).parse("Invalid element %{token}") do |str|
          PeriodicTable[str.strip]?
        end
        mass = ele.mass + @pull.at?(34, 2)
          .parse_if_present("Invalid mass difference %{token}", default: 0, &.to_i?)
        chg = @pull.at?(36, 3)
          .parse_if_present("Invalid formal charge %{token}", default: 0) do |str|
            parse_formal_charge str
          end
        builder.atom ele, pos, formal_charge: chg, mass: mass
        @pull.next_line
      end

      n_bonds.times do
        i = @pull.at(0, 3).int("Invalid atom index %{token}")
        j = @pull.at(3, 3).int("Invalid atom index %{token}")
        @pull.at(6, 3).parse("Invalid bond type %{token}") do |str|
          case bond_type = str.strip
          when "1", "2", "3"
            builder.bond i, j, BondOrder.from_value(bond_type.to_i)
          when "4"
            builder.bond i, j, aromatic: true
          end
        end
        @pull.next_line
      end

      @pull.each_line do
        next unless @pull.at?(0, 3).str? == "M  "

        property_name = @pull.at?(3, 3).str?
        break if property_name == "END"
        next unless property_name.in?("CHG", "ISO")

        n_entries = @pull.at(6, 3).int "Invalid number of entries"
        @pull.error("Number of entries expected within 1 to 8") unless n_entries.in?(1..8)
        n_entries.times do |i|
          col = 9 + i * 8
          atom_i = @pull.at(col, 4).int "Invalid atom index"
          atom = builder.atom?(atom_i) || @pull.error("Atom index #{atom_i} out of range")
          @pull.at(col + 4, 4)
          case property_name
          when "CHG"
            atom.formal_charge = @pull.int "Invalid formal charge %{token}"
          when "ISO"
            atom.mass = @pull.float "Invalid isotope mass %{token}"
          end
        end
      end
    end

    # TODO: add support for continuation line '-'
    private def parse_block_v3000(builder : Structure::Builder) : Nil
      @pull.each_line do
        case {@pull.next_s?, @pull.next_s?}
        when {"M", "V30"}
          next unless @pull.next_s == "BEGIN"
        when {"M", "END"}
          @pull.next_line
          break
        else # line should not be consumed
          @pull.rewind_line
          break
        end

        n_atoms = n_bonds = 0
        case @pull.next_s.tap { @pull.next_line }
        when "CTAB"
          check_v3000
          if @pull.next_s? != "COUNTS"
            @pull.rewind_line
            @pull.error "Expected COUNTS line after BEGIN CTAB"
          end
          n_atoms = @pull.next_i "Invalid number of atoms %{token}"
          n_bonds = @pull.next_i "Invalid number of bonds %{token}"
        when "ATOM"
          n_atoms.times do
            check_v3000
            serial = @pull.next_i "Invalid atom serial %{token}"
            ele = @pull.parse_next("Invalid element %{token}") do |str|
              PeriodicTable[str]?
            end
            x = @pull.next_f "Invalid X coordinate %{token}"
            y = @pull.next_f "Invalid Y coordinate %{token}"
            z = @pull.next_f "Invalid Z coordinate %{token}"
            pos = Spatial::Vec3.new(x, y, z)
            @pull.next_token # skip aamap

            chg = 0
            mass = ele.mass
            while str = @pull.next_s?
              name, _, str = str.partition("=")
              case name
              when "CHG"
                chg = str.to_i? || @pull.error("Invalid formal charge %{token}")
              when "MASS"
                mass = str.to_f? || @pull.error("Invalid isotope mass %{token}")
              end
            end

            builder.atom ele, pos, formal_charge: chg, mass: mass
            @pull.next_line
          end

          if @pull.line.split == %w(M V30 END ATOM)
            @pull.next_line
          else
            @pull.error "Expected END ATOM line after atoms"
          end
        when "BOND"
          n_bonds.times do
            check_v3000
          end
        end
      end
    end

    private def parse_formal_charge(str) : Int32?
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
  end
end
