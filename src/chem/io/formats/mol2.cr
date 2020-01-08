module Chem::Mol2
  enum RecordType
    Molecule
    Atom
    Bond
  end

  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Writer < IO::Writer(AtomCollection)
    @atom_table = {} of Atom => Int32
    @res_table = {} of Residue => Int32

    def write(atoms : AtomCollection) : Nil
      check_open
      reset_index
      write_header "",
        atoms.n_atoms,
        atoms.bonds.size,
        atoms.each_atom.map(&.residue).uniq.sum { 1 }
      section "atom" { atoms.each_atom { |atom| write atom } }
      section "bond" { atoms.bonds.each_with_index { |bond, i| write bond, i + 1 } }
    end

    def write(structure : Structure) : Nil
      check_open
      reset_index
      write_header structure.title,
        structure.n_atoms,
        structure.bonds.size,
        structure.n_residues
      section "atom" { structure.each_atom { |atom| write atom } }
      section "bond" { structure.bonds.each_with_index { |bond, i| write bond, i + 1 } }
      section "substructure" { structure.each_residue { |res| write res } }
    end

    private def atom_index(atom : Atom) : Int32
      @atom_table[atom] ||= @atom_table.size + 1
    end

    private def reset_index
      @atom_table.clear
      @res_table.clear
    end

    private def residue_index(residue : Residue) : Int32
      @res_table[residue] ||= @res_table.size + 1
    end

    private def section(name : String, &block : ->)
      @io << "@<TRIPOS>" << name.upcase << '\n'
      yield
      @io.puts
    end

    private def write(atom : Atom)
      @io.printf "%5d %-4s%10.4f%10.4f%10.4f %-4s%4d %3s%-4d%8.4f\n",
        atom_index(atom),
        atom.name,
        atom.x,
        atom.y,
        atom.z,
        atom.element.symbol,
        residue_index(atom.residue),
        atom.residue.name,
        atom.residue.number,
        atom.partial_charge
    end

    private def write(bond : Bond, i : Int32)
      @io.printf "%5d%5d%5d%2d\n",
        i,
        atom_index(bond.first),
        atom_index(bond.second),
        bond.order
    end

    private def write(residue : Residue)
      @io.printf "%4d %-3s%-4d %5d %-8s %1d %1s %3s %2d\n",
        residue_index(residue),
        residue.name[..2],
        residue.number,
        1,         # root_atom
        "RESIDUE", # subst_type
        1,         # dict_type
        residue.chain.id,
        residue.name[..2],
        residue.bonds.size # inter_bonds
    end

    private def write_header(title, n_atoms, n_bonds, n_residues)
      section "molecule" do
        @io.puts title.gsub(/ *\n */, ' ')
        @io.printf "%5d%5d%4d\n", n_atoms, n_bonds, n_residues
        @io.puts "UNKNOWN"
        @io.puts "USER_CHARGES"
      end
    end
  end

  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Parser < Structure::Parser
    include IO::PullParser

    def next : Structure | Iterator::Stop
      skip_to_record :molecule
      eof? ? stop : parse_next
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

    private def parse_next : Structure
      Structure.build(guess_topology: false) do |builder|
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

    private def read_element : Element
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
