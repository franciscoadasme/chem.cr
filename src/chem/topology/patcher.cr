module Chem::Topology
  class Patcher
    getter unmatched_atoms = [] of Atom

    def initialize(@residues : ResidueCollection)
    end

    def match_and_patch : Nil
      @residues.each_residue do |residue|
        if res_t = residue.type
          patch residue, res_t
        else
          @unmatched_atoms.concat residue.each_atom
        end
      end
    end

    def patch(atom : Atom, atom_t : AtomType) : Nil
      atom.formal_charge = atom_t.formal_charge
    end

    def patch(lhs : Residue, rhs : Residue, bond_t : BondType) : Nil
      if (i = lhs[bond_t[0]]?) && (j = rhs[bond_t[1]]?) && !i.bonded?(j)
        i.bonds.add j, bond_t.order if i.within_covalent_distance?(j)
      end
    end

    def patch(residue : Residue, res_t : ResidueType) : Nil
      residue.each_atom do |atom|
        if atom_t = res_t[atom.name]?
          patch atom, atom_t
        else
          @unmatched_atoms << atom
        end
      end

      res_t.bonds.each { |bond_t| patch residue, residue, bond_t }
      if bond_t = res_t.link_bond
        patch_link_bond residue, bond_t
      end
    end

    def patch_link_bond(residue : Residue, bond_t : BondType)
      if prev_res = residue.previous
        patch prev_res, residue, bond_t
      end
      if next_res = residue.next
        patch residue, next_res, bond_t
      end
    end
  end
end
