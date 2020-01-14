require "./templates/all"

module Chem::Topology::Perception
  extend self

  MAX_CHAINS          =  62 # chain id is alphanumeric: A-Z, a-z or 0-9
  MAX_COVALENT_RADIUS = 5.0

  def assign_templates(structure : Structure, unknown_residues : Array(Residue)? = nil) : Nil
    structure.each_residue do |residue|
      if res_t = Templates[residue.name]?
        assign_bonds residue, res_t
        assign_formal_charges residue, res_t
      else
        unknown_residues.try &.<<(residue)
      end
    end
  end

  def guess_bonds(structure : Structure) : Nil
    kdtree = Spatial::KDTree.new structure, radius: MAX_COVALENT_RADIUS
    guess_connectivity kdtree, structure
    guess_bond_orders structure if structure.has_hydrogens?
  end

  def guess_formal_charges(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      atom.formal_charge = if atom.element.ionic?
                             atom.max_valency
                           else
                             atom.valency - atom.nominal_valency
                           end
    end
  end

  # Guesses residues from existing bonds.
  #
  # Atoms are split in fragments, where each fragment is mapped to a list of residues.
  # Then, fragments are divided into polymers (e.g., peptide) and non-polymer
  # fragments (e.g., water), where residues assigned to the latter are grouped
  # together by their kind (i.e., protein, ion, solvent, etc.). Finally, polymer
  # fragments and residues grouped by kind are assigned to their own unique chain as
  # long as there are less residue groups than the chain limit (62), otherwise all
  # residues are assigned to the same chain.
  def guess_residues(structure : Structure) : Nil
    matches_per_fragment = detect_residues structure
    builder = Structure::Builder.new structure.clear
    matches_per_fragment.each do |matches|
      builder.chain do
        matches.each do |m|
          residue = builder.residue m.resname
          residue.kind = m.reskind
          m.each_atom do |atom, atom_name|
            atom.name = atom_name
            atom.residue = residue
          end
        end
      end
    end
  end

  def guess_topology(structure : Structure, use_templates : Bool? = nil) : Nil
    return unless structure.n_atoms > 0
    use_templates ||= structure.n_residues > 1 || structure.each_residue.first.name != "UNK"
    if use_templates
      unknown_residues = [] of Residue
      assign_templates structure, unknown_residues
      sanitize_residues structure, unknown_residues unless unknown_residues.empty?
    else
      guess_bonds structure
      guess_formal_charges structure if structure.has_hydrogens?
      guess_residues structure
      renumber_by_connectivity structure
    end
  end

  def renumber_by_connectivity(structure : Structure) : Nil
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

  private def detect_residues(atoms : AtomCollection) : Array(Array(MatchData))
    fragments = [] of Array(MatchData)
    atoms.each_fragment do |frag|
      detector = Templates::Detector.new frag
      matches = [] of MatchData
      matches.concat detector.matches
      matches.concat guess_unmatched(detector.unmatched_atoms)
      fragments << matches
    end

    polymers, other = fragments.partition &.size.>(1)
    other = other.flatten.sort_by!(&.reskind).group_by(&.reskind).values
    polymers.size + other.size <= MAX_CHAINS ? polymers + other : [fragments.flatten]
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

  private def guess_connectivity(kdtree : Spatial::KDTree, atoms : AtomCollection) : Nil
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

  private def guess_previous_residue(residue : Residue, link_bond : BondType) : Residue?
    prev_res = nil
    if atom = residue[link_bond.second]?
      prev_res = atom.each_bonded_atom.find(&.name.==(link_bond.first)).try &.residue
      prev_res ||= atom.each_bonded_atom.find do |atom|
        element = PeriodicTable[atom_name: link_bond.first]
        atom.element == element && atom.residue != residue
      end.try &.residue
    else
      elements = {PeriodicTable[atom_name: link_bond.first],
                  PeriodicTable[atom_name: link_bond.second]}
      residue.each_atom do |atom|
        next unless atom.element == elements[1]
        prev_res = atom.each_bonded_atom.find do |atom|
          atom.element == elements[0] && atom.residue != residue
        end.try &.residue
        break if prev_res
      end
    end
    prev_res
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

  private def guess_unmatched(atoms : Array(Atom)) : Array(MatchData)
    matches = [] of MatchData
    AtomView.new(atoms).each_fragment do |frag|
      atom_map = Hash(String, Atom).new initial_capacity: frag.size
      ele_index = Hash(Element, Int32).new default_value: 0
      frag.each do |atom|
        name = "#{atom.element.symbol}#{ele_index[atom.element] += 1}"
        atom_map[name] = atom
      end
      matches << MatchData.new("UNK", :other, atom_map)
    end
    matches
  end

  private def sanitize_residues(structure : Structure, residues : Array(Residue)) : Nil
    kdtree = Spatial::KDTree.new structure, radius: MAX_COVALENT_RADIUS
    residues.each do |residue|
      residue.kind = guess_residue_type residue
      guess_connectivity kdtree, residue
      if structure.has_hydrogens?
        guess_bond_orders residue
        guess_formal_charges residue
      end
    end
  end
end
