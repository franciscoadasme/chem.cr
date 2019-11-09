module Chem
  class Atom
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.atom_index(self), width: 5
      mol2.space
      mol2.string name, width: 4
      coords.to_mol2 mol2
      mol2.space
      element.to_mol2 mol2 # atom_type
      mol2.number mol2.residue_index(residue), width: 4
      mol2.space
      mol2.string residue.name, width: 3
      mol2.number residue.number, alignment: :left, width: 4
      mol2.number partial_charge, precision: 4, width: 8
      mol2.newline
    end
  end

  module AtomCollection
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.atoms = n_atoms
      mol2.bonds = bonds.size
      mol2.residues = n_residues
      mol2.title = title

      mol2.object do
        mol2.section "atom" { each_atom &.to_mol2(mol2) }
        mol2.section "bond" { bonds.each &.to_mol2(mol2) }
        mol2.section "substructure" { each_residue &.to_mol2(mol2) }
      end
    end
  end

  class Bond
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.next_bond_index, width: 5
      mol2.number mol2.atom_index(first), width: 5
      mol2.number mol2.atom_index(second), width: 5
      mol2.number order, width: 2
      mol2.newline
    end
  end

  class Element
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.string @symbol, width: 4
    end
  end

  class Residue
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number mol2.residue_index(self), width: 4
      mol2.space
      mol2.string name[..2], width: 3
      mol2.number number, alignment: :left, width: 4
      mol2.space
      mol2.number 1, width: 5 # root_atom
      mol2.space
      mol2.string "RESIDUE" # subst_type
      mol2.space
      mol2.number 1 # dict_type
      mol2.space
      mol2.string chain.id
      mol2.space
      mol2.string name[..2], width: 3
      mol2.space
      mol2.number 1 # inter_bonds
    end
  end

  struct Spatial::Vector
    def to_mol2(mol2 : Mol2::Builder) : Nil
      mol2.number x, precision: 4, width: 10
      mol2.number y, precision: 4, width: 10
      mol2.number z, precision: 4, width: 10
    end
  end
end
