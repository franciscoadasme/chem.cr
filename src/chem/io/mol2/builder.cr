module Chem::Mol2
  @[IO::FileType(format: Mol2, ext: [:mol2])]
  class Builder < IO::Builder
    setter atoms = 0
    setter bonds = 0
    setter residues = 0
    setter title = ""

    def initialize(@io : ::IO)
      @atom_index_table = {} of Int32 => Int32
      @bond_index = 0
      @resnum_table = {} of Int32 => Int32
    end

    def atom_index(atom : Atom) : Int32
      @atom_index_table[atom.serial] ||= @atom_index_table.size + 1
    end

    def next_bond_index : Int32
      @bond_index += 1
    end

    def residue_index(residue : Residue) : Int32
      @resnum_table[residue.number] ||= @resnum_table.size + 1
    end

    def object_header : Nil
      @atom_index_table.clear
      @bond_serial = 0
      @resnum_table.clear

      section "molecule" do
        string @title
        newline
        number @atoms, width: 5
        number @bonds, width: 5
        number @residues, width: 4
        newline
        string "UNKNOWN"
        newline
        string "USER_CHARGES"
        newline
      end
    end

    def section(name : String, &block : ->) : Nil
      string "@<TRIPOS>"
      string name.upcase
      newline
      yield
      newline
    end
  end
end
