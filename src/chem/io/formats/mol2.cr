module Chem::Mol2
  @[IO::FileType(format: Mol2, encoded: AtomCollection, ext: %w(mol2))]
  class Writer
    include IO::Writer(AtomCollection)

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

  @[IO::FileType(format: Mol2, encoded: Structure, ext: %w(mol2))]
  class Reader
    include IO::Reader(Structure)
    include IO::TextReader(Structure)
    include IO::MultiReader(Structure)

    TAG          = "@<TRIPOS>"
    TAG_ATOMS    = "@<TRIPOS>ATOM"
    TAG_BONDS    = "@<TRIPOS>BOND"
    TAG_MOLECULE = "@<TRIPOS>MOLECULE"

    needs guess_topology : Bool = true

    @builder = uninitialized Structure::Builder
    @include_charges = true
    @n_atoms = 0
    @n_bonds = 0
    @title = ""

    def read_next : Structure?
      check_open
      return if @io.skip_whitespace.eof?
      read_header
      @builder = Structure::Builder.new guess_topology: false
      @builder.title @title
      until @io.eof?
        case @io.skip_whitespace
        when .check(TAG_ATOMS)
          @io.skip_line
          @n_atoms.times { read_atom }
        when .check(TAG_BONDS)
          @io.skip_line
          @n_bonds.times { read_bond }
        when .check(TAG_MOLECULE)
          break
        else
          @io.skip_line
        end
      end
      @builder.build
    end

    def skip : Nil
      @io.skip_line if @io.skip_whitespace.check(TAG_MOLECULE)
      skip_until_tag TAG_MOLECULE
    end

    private def read_atom : Atom
      serial = @io.read_int
      name = @io.skip_spaces.scan 'A'..'z', '0'..'9'
      coords = @io.read_vector
      element = PeriodicTable[@io.read_word]
      @io.skip('.').skip_word if @io.check('.') # ignore sybyl type
      unless @io.eol?
        resid = @io.read_int
        resname = @io.skip_spaces.read_word
        @builder.residue resname[..2], resid
        charge = @io.read_float if @include_charges
      end
      @io.skip_line
      @builder.atom name, coords, element: element, partial_charge: (charge || 0.0)
    end

    private def read_bond : Nil
      serial = @io.read_int
      i = @io.read_int - 1
      j = @io.read_int - 1
      bond_type = @io.skip_spaces.scan('a'..'z', '0'..'9')
      bond_order = case bond_type
                   when "1", "2", "3"    then bond_type.to_i
                   when "am", "ar", "du" then 1
                   else                       0
                   end
      @io.skip_line
      @builder.bond i, j, bond_order, aromatic: bond_type == "ar" if bond_order > 0
    end

    private def read_header : Nil
      skip_until_tag TAG_MOLECULE
      parse_exception "Invalid tag for structure" if @io.eof?
      @io.skip_line

      @title = @io.read_line.strip
      @n_atoms = @io.read_int
      @n_bonds = @io.read_int
      @io.skip_line
      @io.skip_line
      @include_charges = @io.read_line.strip != "NO_CHARGES"
    end

    private def skip_until_tag(tag : String) : Nil
      until @io.eof?
        break if @io.skip_whitespace.check(tag)
        @io.skip_line
      end
    end
  end
end
