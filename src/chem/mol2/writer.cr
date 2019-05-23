module Chem::Mol2
  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Writer < IO::Writer
    def initialize(@io : ::IO)
      @atom_serial_table = {} of Int32 => Int32
      @bond_serial = 1
      @resnum_table = {} of Int32 => Int32
    end

    def <<(structure : Structure) : self
      write_header structure
      self << structure.atoms
      self << structure.bonds
      self << structure.residues
      self
    end

    private def <<(atom : Atom) : Nil
      @io.printf "%5d %-4s%10.4f%10.4f%10.4f %-4s%4d %3s%-4d%8.4f\n",
        (@atom_serial_table[atom.serial] ||= @atom_serial_table.size + 1),
        atom.name,
        atom.x,
        atom.y,
        atom.z,
        guess_atom_type(atom),
        (@resnum_table[atom.residue.number] ||= @resnum_table.size + 1),
        atom.residue.name,
        atom.residue.number,
        atom.partial_charge
    end

    private def <<(atoms : Enumerable(Atom)) : Nil
      write_record "atom" do
        atoms.each { |atom| self << atom }
      end
    end

    private def <<(bond : Bond) : Nil
      @io.printf "%5d%5d%5d%2d\n",
        @bond_serial,
        @atom_serial_table[bond[0].serial],
        @atom_serial_table[bond[1].serial],
        bond.order
    end

    private def <<(bonds : Enumerable(Bond)) : Nil
      @bond_serial = 1
      write_record "bond" do
        bonds.each do |bond|
          self << bond
          @bond_serial += 1
        end
      end
    end

    private def <<(residue : Residue) : Nil
      @io.printf "%4d %3s%-4d %5d %-7s %d %s %3s %d\n",
        @resnum_table[residue.number],
        residue.name[..2],
        residue.number,
        1,         # root_atom
        "RESIDUE", # subst_type
        1,         # dict_type
        residue.chain.id,
        residue.name[..2],
        1 # inter_bonds
    end

    private def <<(residues : Enumerable(Residue)) : Nil
      write_record "substructure" do
        residues.each { |residue| self << residue }
      end
    end

    private def guess_atom_type(atom : Atom) : String
      atom.element.symbol
    end

    private def guess_mol_type(structure : Structure) : String
      "PROTEIN"
    end

    private def write_header(structure : Structure) : Nil
      write_record "molecule" do |io|
        io.puts structure.title
        io.printf "%5d%5d%4d\n",
          structure.n_atoms,
          structure.bonds.size,
          structure.n_residues
        io.puts guess_mol_type(structure)
        io.puts "USER_CHARGES"
      end
    end

    private def write_record(name : String, &block : ::IO ->) : Nil
      @io << "@<TRIPOS>" << name.upcase << '\n'
      yield @io
      @io.puts
    end
  end
end
