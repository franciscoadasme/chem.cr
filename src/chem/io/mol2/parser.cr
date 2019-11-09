module Chem::Mol2
  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Parser < IO::Parser
    include IO::PullParser

    def next : Structure | Iterator::Stop
      skip_to_record :molecule
      eof? ? stop : parse
    end

    def skip_structure : Nil
      skip_line if record? :molecule
      skip_to_record :molecule
    end

    private def guess_bond_order(bond_type : String) : Int32
      case bond_type
      when "am", "ar", "du"
        1
      when "un", "nc"
        0
      else
        bond_type.to_i
      end
    end

    private def parse : Structure
      Structure.build do |builder|
        skip_line
        builder.title read_line.strip
        n_atoms = read_int
        n_bonds = read_int
        skip_line

        while name = next_record
          case name
          when .atom?
            n_atoms.times { parse_atom builder }
          when .bond?
            n_bonds.times { parse_bond builder }
          when .molecule?
            @io.pos = @prev_pos
            break
          end
        end
      end
    end

    private def next_record : RecordType?
      until eof?
        if record_type = read_record
          return record_type
        else
          skip_line
        end
      end
    end

    private def parse_atom(builder : Structure::Builder) : Nil
      skip_whitespace
      skip_index
      name = scan_in_set "a-zA-Z0-9"
      coords = read_vector
      element = read_element
      skip('.').skip_in_set("A-z0-9").skip_spaces # skip atom type
      unless check(&.whitespace?)
        resid = read_int
        resname = skip_spaces.scan_in_set "A-z0-9"
        builder.residue resname[..2], resid
      end
      charge = read_float unless skip_spaces.check(&.whitespace?)
      skip_line
      builder.atom name, coords, element: element, partial_charge: (charge || 0.0)
    end

    private def parse_bond(builder : Structure::Builder) : Nil
      skip_index
      i = read_int - 1
      j = read_int - 1
      bond_type = skip_spaces.scan(/[a-z0-9]+/).to_s
      bond_order = guess_bond_order bond_type
      builder.bond i, j, bond_order, aromatic: bond_type == "ar" if bond_order > 0
      skip_line
    end

    private def read_element : PeriodicTable::Element
      PeriodicTable[skip_spaces.scan_in_set("A-z")]
    end

    private def read_record : RecordType?
      skip_whitespace
      return unless check "@<TRIPOS>"
      name = read { skip(9).read_line.rstrip.downcase }
      RecordType.parse? name
    end

    private def record?(type : RecordType) : Bool
      if record_type = read_record
        @io.pos = @prev_pos
        record_type == type
      else
        false
      end
    end

    private def skip_index : self
      skip_spaces.skip_in_set("0-9").skip_spaces
    end

    private def skip_to_record(type : RecordType) : Nil
      until eof?
        break if record? type
        skip_line
      end
    end
  end
end
