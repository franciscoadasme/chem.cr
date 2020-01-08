require "./templates/all"

module Chem::Topology::Guesser
  extend self

  MAX_CHAINS = 62 # chain id is alphanumeric: A-Z, a-z or 0-9

  def guess_residue_numbering_from_connectivity(structure : Structure) : Nil
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
    unknown_residues = [] of Residue
    structure.each_residue do |residue|
      if res_t = Templates[residue.name]?
        residue.kind = res_t.kind
        assign_bonds residue, res_t
        assign_formal_charges residue, res_t
      else
        unknown_residues << residue
      end
    end

    unless unknown_residues.empty?
      radar = ConnectivityRadar.new structure
      unknown_residues.each do |residue|
        residue.kind = guess_residue_type residue
        radar.detect_bonds residue
      end
    end
  end

  private def assign_bond(residue : Residue, other : Residue, bond_t : BondType) : Nil
    if (i = residue[bond_t.first]?) && (j = other[bond_t.second]?) && !i.bonded?(j)
      i.bonds.add j, bond_t.order if i.within_covalent_distance?(j)
    end
  end

  private def assign_bonds(residue : Residue, res_t : ResidueType) : Nil
    res_t.bonds.each { |bond_t| assign_bond residue, residue, bond_t }
    if bond_t = res_t.link_bond
      if prev_res = residue.previous
        assign_bond prev_res, residue, bond_t
      end
      if next_res = residue.next
        assign_bond residue, next_res, bond_t
      end
    end
  end

  private def assign_formal_charges(residue : Residue, res_t : ResidueType) : Nil
    res_t.each_atom_type do |atom_t|
      next unless atom = residue[atom_t.name]?
      atom.formal_charge = atom_t.formal_charge
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

  private def guess_residue_type(res : Residue) : Residue::Kind
    kind = Residue::Kind::Other
    prev_res, next_res = res.previous, res.next

    if (other = prev_res || next_res) && (bond_t = Templates[other.name]?.try(&.link_bond))
      if prev_res && next_res && prev_res.kind == next_res.kind
        kind = other.kind if prev_res.bonded?(res, bond_t) && res.bonded?(next_res, bond_t)
      elsif prev_res
        kind = prev_res.kind if prev_res.bonded?(res, bond_t)
      elsif next_res
        kind = next_res.kind if res.bonded?(next_res, bond_t)
      end
    end

    kind
  end
end
