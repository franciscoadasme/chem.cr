require "./topology/*"

module Chem::Topology
  extend self

  def guess_topology(of system : System)
    system.each_residue { |residue| find_and_assign_template to: residue }
  end

  private def assign_bond(bond_t : Templates::Bond,
                          residue : Residue,
                          other : Residue? = nil)
    other ||= residue
    return unless atom1 = residue.atoms[bond_t[0]]?
    return unless atom2 = other.atoms[bond_t[1]]?
    return unless atom1.within_covalent_distance? of: atom2
    atom1.bonds.add atom2, bond_t.order
  end

  private def assign_bonds(from res_t : Templates::Residue, to residue : Residue)
    res_t.bonds.each { |bond_t| assign_bond bond_t, residue }
    if (bond_t = res_t.link_bond) && (next_res = residue.next)
      assign_bond bond_t, residue, next_res
    end
  end

  private def assign_charges(from res_t : Templates::Residue, to residue : Residue)
    res_t.each_atom_type do |atom_type|
      next unless atom = residue.atoms[atom_type.name]?
      atom.charge = atom_type.formal_charge
    end
  end

  private def find_and_assign_template(to residue : Residue)
    return unless res_t = Templates[residue.name]?
    residue.kind = Residue::Kind.from_value res_t.kind.to_i
    assign_bonds from: res_t, to: residue
    assign_charges from: res_t, to: residue
  end
end
