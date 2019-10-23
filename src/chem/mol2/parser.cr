module Chem::Mol2
  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Parser < IO::Parser
    include IO::PullParser

    def initialize(input : ::IO | Path | String)
      super
      @n_atoms = @n_bonds = 0
    end

    def next : Structure | Iterator::Stop
      skip_to_record "molecule"
      eof? ? stop : parse
    end

    def skip_structure : Nil
      skip_line if check "@<TRIPOS>MOLECULE"
      skip_to_record "molecule"
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
        parse_info

        while name = next_record
          case name
          when "atom"
            @n_atoms.times { parse_atom builder }
          when "bond"
            parse_bonds builder.build.atoms
          when "molecule"
            @io.pos = @prev_pos
            break
          end
        end
      end
    end

    private def next_record : String?
      until eof?
        skip_whitespace
        if check "@<TRIPOS>"
          return read { skip(9).read_line.rstrip.downcase }
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

    private def parse_bonds(atoms : Indexable(Atom)) : Nil
      aromatic_bonds = [] of Bond
      @n_bonds.times do
        skip_index
        atom = atoms[read_int - 1]
        other = atoms[read_int - 1]
        bond_type = skip_spaces.scan(/[a-z0-9]+/).to_s
        bond_order = guess_bond_order bond_type
        if bond_order > 0
          bond = Bond.new atom, other, bond_order
          atom.bonds.add bond
          aromatic_bonds << bond if bond_type == "ar"
        end
        skip_line
      end
      transform_aromatic_bonds aromatic_bonds
    end

    private def parse_info : Nil
      @n_atoms = read_int
      @n_bonds = read_int
      3.times { skip_line } # rest of line, mol_type, charge_type
      skip_line unless check &.whitespace? # status_bits
      skip_line unless check &.whitespace? # comment
    end

    private def read_element : PeriodicTable::Element
      PeriodicTable[skip_spaces.scan_in_set("A-z")]
    end

    private def skip_index : self
      skip_spaces.skip_in_set("0-9").skip_spaces
    end

    private def skip_to_record(name : String) : Nil
      while record_name = next_record
        if record_name == name
          @io.pos = @prev_pos
          break
        end
      end
    end

    private def transform_aromatic_bonds(bonds : Array(Bond))
      bonds.sort_by! { |bond| Math.min bond[0].serial, bond[1].serial }
      until bonds.empty?
        bond = bonds.shift
        if other = bonds.find { |b| b.includes?(bond[0]) || b.includes?(bond[1]) }
          bonds.delete other
          (bond[1] != other[0] ? bond : other).order = 2
        end
      end
    end
  end
end
