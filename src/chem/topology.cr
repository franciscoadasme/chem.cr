require "./topology/builder"
require "./topology/templates"

module Chem::Topology
  extend self

  def guess_topology(of structure : Structure)
    structure.each_residue { |residue| find_and_assign_template to: residue }
    guess_unknown_residue_types of: structure
  end

  private def assign_bond(bond_t : Templates::Bond,
                          residue : Residue,
                          other : Residue? = nil)
    other ||= residue
    return unless atom1 = residue.atoms[bond_t[0]]?
    return unless atom2 = other.atoms[bond_t[1]]?
    return if atom1.bonded? atom2
    return unless atom1.within_covalent_distance? of: atom2
    atom1.bonds.add atom2, bond_t.order
  end

  private def assign_bonds(from res_t : Templates::ResidueType, to residue : Residue)
    res_t.bonds.each { |bond_t| assign_bond bond_t, residue }
    return unless bond_t = res_t.link_bond
    if prev_res = residue.previous
      assign_bond bond_t, prev_res, residue
    end
    if next_res = residue.next
      assign_bond bond_t, residue, next_res
    end
  end

  private def assign_charges(from res_t : Templates::ResidueType, to residue : Residue)
    res_t.each_atom_type do |atom_type|
      next unless atom = residue.atoms[atom_type.name]?
      atom.formal_charge = atom_type.formal_charge
    end
  end

  private def find_and_assign_template(to residue : Residue)
    return unless res_t = Templates[residue.name]?
    residue.kind = Residue::Kind.from_value res_t.kind.to_i
    assign_bonds from: res_t, to: residue
    assign_charges from: res_t, to: residue
  end

  private def guess_unknown_residue_types(of structure : Structure)
    structure.each_residue.select(&.other?).each do |res|
      if (prev_res = res.previous) && (next_res = res.next)
        next unless prev_res.kind == next_res.kind
        next unless res.bonded? prev_res
        next unless res.bonded? next_res
        res.kind = next_res.kind
      elsif prev_res = res.previous
        res.kind = prev_res.kind if res.bonded? prev_res
      elsif next_res = res.next
        res.kind = next_res.kind if res.bonded? next_res
      end
    end
  end
end
