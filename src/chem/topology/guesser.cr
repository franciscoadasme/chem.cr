require "./templates/all"

module Chem::Topology::Guesser
  extend self

  MAX_CHAINS          =  62 # chain id is alphanumeric: A-Z, a-z or 0-9
  MAX_COVALENT_RADIUS = 5.0

  def guess_bonds_from_geometry(structure : Structure, atoms : AtomCollection? = nil) : Nil
    atoms ||= structure
    guess_connectivity_from_geometry structure, atoms
    guess_bond_orders atoms
    guess_formal_charges atoms
  end

  def guess_residue_numbering_from_connectivity(structure : Structure) : Nil
    raise ArgumentError.new "Structure has no bonds" if structure.bonds.empty?
    structure.each_chain do |chain|
      next unless chain.n_residues > 1
      next unless link_bond = chain.each_residue.compact_map do |residue|
                    Templates[residue.name]?.try &.link_bond
                  end.first?

      res_map = chain.each_residue.to_h do |residue|
        {guess_previous_residue(residue, link_bond), residue}
      end
      res_map[nil] = chain.residues.first unless res_map.has_key? nil

      prev_res = nil
      chain.n_residues.times do |i|
        next_res = res_map[prev_res]
        next_res.number = i + 1
        prev_res = next_res
      end
      chain.reset_cache
    end
  end

  # Guesses topology (chain, residue and atom names) from existing bonds.
  #
  # Atoms are split in fragments, where each fragment is mapped to a list of residues.
  # Then, fragments are divided into polymers (e.g., peptide) and non-polymer
  # fragments (e.g., water), where residues assigned to the latter are grouped
  # together by their kind (i.e., protein, ion, solvent, etc.). Finally, polymer
  # fragments and residues grouped by kind are assigned to their own unique chain as
  # long as there are less residue groups than the chain limit (62), otherwise all
  # residues are assigned to the same chain.
  def guess_topology_from_connectivity(structure : Structure) : Nil
    raise ArgumentError.new "Structure has no bonds" if structure.bonds.empty?
    return unless old_chain = structure.delete(structure.chains.first)

    fragments = old_chain.fragments.map do |atoms|
      guess_residues old_chain, atoms.to_a
    end

    polymer_chains, other = fragments.partition { |frag| frag.size > 1 }
    other = other.flatten.sort_by!(&.kind.to_i).group_by(&.kind).values
    if polymer_chains.size + other.size <= MAX_CHAINS
      fragments = polymer_chains + other
    else
      fragments = [fragments.flatten]
    end

    builder = Structure::Builder.new(structure)
    fragments.each do |residues|
      builder.chain do |chain|
        chain = builder.chain
        residues.each do |residue|
          residue.number = chain.n_residues + 1
          residue.chain = chain
        end
      end
    end
  end

  def guess_topology_from_templates(structure : Structure) : Nil
    structure.each_residue do |residue|
      next unless res_t = Templates[residue.name]?

      residue.kind = res_t.kind
      res_t.bonds.each { |bond_t| assign_bond_from_template residue, residue, bond_t }
      if bond_t = res_t.link_bond
        if prev_res = residue.previous
          assign_bond_from_template prev_res, residue, bond_t
        end
        if next_res = residue.next
          assign_bond_from_template residue, next_res, bond_t
        end
      end

      res_t.each_atom_type do |atom_type|
        next unless atom = residue[atom_type.name]?
        atom.formal_charge = atom_type.formal_charge
      end
    end

    guess_unknown_residue_types structure
  end

  private def assign_bond_from_template(residue : Residue,
                                        other : Residue,
                                        bond_t : Topology::BondType) : Nil
    if (i = residue[bond_t.first]?) && (j = other[bond_t.second]?) && !i.bonded?(j)
      i.bonds.add j, bond_t.order if i.within_covalent_distance?(j)
    end
  end

  private def guess_bond_orders(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      next if atom.element.ionic?
      missing_bonds = atom.missing_valency
      while missing_bonds > 0
        others = atom.bonded_atoms.select &.missing_valency.>(0)
        break if others.empty?
        others.each(within: ...missing_bonds) do |other|
          atom.bonds[other].order += 1
          missing_bonds -= 1
        end
      end
    end
  end

  private def guess_connectivity_from_geometry(structure : Structure,
                                               atoms : AtomCollection) : Nil
    kdtree = Spatial::KDTree.new structure, structure.periodic?, radius: MAX_COVALENT_RADIUS
    atoms.each_atom do |atom|
      next if atom.element.ionic?
      kdtree.each_neighbor(atom, within: MAX_COVALENT_RADIUS) do |other, d|
        next if other.element.ionic? ||
                atom.bonded?(other) ||
                other.valency >= other.max_valency ||
                d > PeriodicTable.covalent_cutoff(atom, other)
        if atom.element.hydrogen? && atom.bonds.size == 1
          next unless d < atom.bonds[0].squared_distance
          atom.bonds.delete atom.bonds[0]
        end
        atom.bonds.add other
      end
    end
  end

  private def guess_formal_charges(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      atom.formal_charge = if atom.element.ionic?
                             atom.max_valency
                           else
                             atom.valency - atom.nominal_valency
                           end
    end
  end

  private def guess_previous_residue(residue : Residue, link_bond : BondType) : Residue?
    prev_res = nil
    if atom = residue[link_bond.second]?
      prev_res = atom.bonded_atoms.find(&.name.==(link_bond.first)).try &.residue
      prev_res ||= atom.bonded_atoms.find do |atom|
        element = PeriodicTable[atom_name: link_bond.first]
        atom.element == element && atom.residue != residue
      end.try &.residue
    else
      elements = {PeriodicTable[atom_name: link_bond.first],
                  PeriodicTable[atom_name: link_bond.second]}
      residue.each_atom do |atom|
        next unless atom.element == elements[1]
        prev_res = atom.bonded_atoms.find do |atom|
          atom.element == elements[0] && atom.residue != residue
        end.try &.residue
        break if prev_res
      end
    end
    prev_res
  end

  private def guess_residues(chain : Chain, atoms : Array(Atom)) : Array(Residue)
    detector = Templates::Detector.new Templates.all
    residues = [] of Residue
    detector.each_match(atoms.dup) do |res_t, atom_map|
      names = res_t.atom_names

      residues << (residue = Residue.new res_t.name, residues.size + 1, chain)
      residue.kind = res_t.kind
      atom_map.to_a.sort_by! { |_, k| names.index(k) || 99 }.each do |atom, name|
        atom.name = name
        atom.residue = residue
        atoms.delete atom
      end
    end

    unless atoms.empty?
      residues << (residue = Residue.new "UNK", chain.residues.size, chain)
      atoms.each &.residue=(residue)
    end

    residues
  end

  private def guess_unknown_residue_types(structure : Structure) : Nil
    structure.each_residue do |res|
      next unless res.kind.other? &&
                  (other = res.previous || res.next) &&
                  (bond_t = Templates[other.name].link_bond)

      if (prev_res = res.previous) && (next_res = res.next)
        next unless prev_res.kind == next_res.kind &&
                    prev_res.bonded?(res, bond_t) &&
                    res.bonded?(next_res, bond_t)
      elsif prev_res = res.previous
        next unless prev_res.bonded?(res, bond_t)
      elsif next_res = res.next
        next unless res.bonded?(next_res, bond_t)
      end

      res.kind = other.kind
    end
  end
end
