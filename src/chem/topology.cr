require "./topology/*"

module Chem::Topology
  extend self

  def assign_bonds_from_templates(system : System)
    system.each_residue do |residue|
      assign_bonds_from_template residue
    end
  end

  def guess_bonds(system : System)
    assign_bonds_from_templates system
  end

  private def assign_bond(bond_t : Templates::Bond,
                          residue : Residue,
                          other : Residue? = nil)
    other ||= residue
    return unless atom1 = residue.atoms[bond_t[0]]?
    return unless atom2 = other.atoms[bond_t[1]]?
    atom1.bonds.add atom2, bond_t.order
  end

  private def assign_bonds_from_template(residue : Residue)
    if res_t = Templates[residue.name]?
      res_t.bonds.each { |bond_t| assign_bond bond_t, residue }
      if (bond_t = res_t.link_bond) && (next_res = residue.next)
        assign_bond bond_t, residue, next_res if next_res.number - residue.number == 1
      end
    end
  end
end
