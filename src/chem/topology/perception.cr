require "./templates/all"

class Chem::Topology::Perception
  MAX_CHAINS = 62 # chain id is alphanumeric: A-Z, a-z or 0-9

  def initialize(@structure : Structure)
  end

  private def assign_formal_charges : Nil
    @structure.each_atom do |atom|
      next unless atom.formal_charge == 0 # don't reset charge if set
      # TODO: replace by atom.valence
      valence = atom.bonds.sum(&.order)
      if valence == 0
        if atom.element.valence_electrons < 4 # monoatomic cations
          atom.formal_charge = atom.element.valence_electrons
        else # monoatomic anions
          target_electrons = atom.element.target_electrons(valence)
          atom.formal_charge = atom.element.valence_electrons - target_electrons
        end
      elsif atom.element.max_valence # skip transition metals and others
        target_electrons = atom.element.target_electrons(valence)
        atom.formal_charge = atom.element.valence_electrons - target_electrons + valence
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
  def guess_residues : Nil
    matches_per_fragment = detect_residues @structure.atoms
    builder = Structure::Builder.new @structure.clear
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
    @structure.renumber_residues_by_connectivity split_chains: false
    assign_residue_types
  end

  def guess_topology : Nil
    return unless @structure.n_atoms > 0

    apply_templates
    build_connectivity
    # skip bond order assignment if a protein chain has missing
    # hydrogens (very common in PDB)
    if !@structure.residues.any? { |res| res.protein? && !res.has_hydrogens? }
      assign_bond_orders @structure.atoms
      assign_formal_charges
    end
    assign_residue_types
  end

  private getter largest_atom : Atom do
    @structure.each_atom.max_by &.covalent_radius
  end

  private getter kdtree : Spatial::KDTree do
    Spatial::KDTree.new(@structure.coords.to_a, @structure.cell)
  end

  # Determines bond orders from connectivity and geometry.
  #
  # First, atom hybridization is guessed from the geometry. Then, the
  # bond orders are determined such that both atoms must have the same
  # hybridization to assign a double (sp2) or triple (sp) bond. Bond
  # order is only changed if the bonded atoms have missing valence. If
  # multiple bonded atoms fulfill the requirements for increasing the
  # bond order, the atom with the most missing valence or that is
  # closest to the current atom is selected first.
  #
  # This algorithm is loosely based on OpenBabel's `PerceiveBondOrders`
  # function.
  private def assign_bond_orders(atoms : AtomView) : Nil
    # TODO: cache valences and missing valences in a hash to avoid
    # computing the valence each cycle
    hybrid_map = guess_hybridization atoms.select { |atom| atom.degree > 0 }
    atoms.select { |atom| hybrid_map[atom]? }
      .sort_by! { |atom| {atom.missing_valence, atom.serial} }
      .each do |atom|
        missing_valence = atom.missing_valence
        next if missing_valence == 0
        atom.bonded_atoms
          .select! do |other|
            hybrid_map[other]? == hybrid_map[atom] && (
              other.missing_valence > 0 ||
                other.valence < (other.element.max_valence || Int32::MAX)
            )
          end
          .sort_by! do |other|
            {-missing_valence, Spatial.distance2(atom, other)}
          end
          .each do |other|
            case hybrid_map[other]
            when 2
              atom.bonds[other].order = 2
              missing_valence -= 1
            when 1
              atom.bonds[other].order = 3
              missing_valence -= 2
            end
            break if missing_valence == 0
          end
      end
  end

  private def assign_residue_types : Nil
    return unless bond_t = @structure.link_bond
    @structure.each_residue do |residue|
      next if residue.type
      types = residue
        .bonded_residues(bond_t, forward_only: false, strict: false)
        .map(&.kind)
        .uniq!
        .reject!(&.other?)
      residue.kind = types.size == 1 ? types[0] : Residue::Kind::Other
    end
  end

  # Assign bonds, formal charges, and residue's kind from templates.
  private def apply_templates : Nil
    prev_res = nil
    @structure.each_residue do |residue|
      if restype = residue.type
        residue.kind = restype.kind
        residue.each_atom do |atom|
          if atom_type = restype[atom.name]?
            atom.formal_charge = atom_type.formal_charge
          end
        end

        restype.bonds.each do |bond_t|
          if (lhs = residue[bond_t[0]]?) &&
             (rhs = residue[bond_t[1]]?) &&
             lhs.within_covalent_distance?(rhs)
            lhs.bonds.add rhs, bond_t.order
          end
        end

        if prev_res &&
           (bond_t = restype.link_bond) &&
           (lhs = prev_res[bond_t[0]]?) &&
           (rhs = residue[bond_t[1]]?) &&
           lhs.within_covalent_distance?(rhs)
          lhs.bonds.add rhs, bond_t.order
        end
      end
      prev_res = residue
    end
  end

  # Add single bonds based on pairwise distances. Bonds are added such
  # that the atom's valence is fulfilled if possible (potential bonds
  # that lead to over-valence are removed). Note that isolated atoms (no
  # bonds) are preferred for elements that could potentially be as
  # cations (K, Na, etc.).
  private def build_connectivity : Nil
    atoms = @structure.atoms

    bond_table = Hash(Atom, Array(Atom)).new
    dcov2_map = Hash({Element, Element}, Float64).new
    elements = Set(Element).new
    largest_atom = atoms.first
    cation_atoms = [] of Atom
    atoms.each do |atom|
      # Add existing bonds
      bond_table[atom] = Array(Atom).new(atom.element.max_bonds)
      atom.each_bonded_atom do |other|
        bond_table[atom] << other
      end

      largest_atom = atom if atom.covalent_radius > largest_atom.covalent_radius

      # Cache covalent distances
      unless atom.element.in?(elements)
        elements << atom.element
        elements.each do |ele|
          dcov2 = PeriodicTable.covalent_distance(atom.element, ele) ** 2
          dcov2_map[{atom.element, ele}] = dcov2_map[{ele, atom.element}] = dcov2
        end
      end

      # Cache atoms that could be cations (Mg2+, K+ or metals)
      if atom.max_valence.nil? || (atom.heavy? && atom.valence_electrons < 4)
        cation_atoms << atom
      end
    end

    # Add potential bonds based on geometry
    kdtree = Spatial::KDTree.new(atoms.map(&.coords), @structure.cell)
    atoms.each do |atom|
      cutoff = Math.sqrt(dcov2_map[{atom.element, largest_atom.element}])
      kdtree.each_neighbor(atom.coords, within: cutoff) do |index, dis2|
        other = atoms.unsafe_fetch(index)
        if atom.serial < other.serial &&                            # check bond once
           other.element.max_bonds > 0 &&                           # skip non-bonding
           !other.in?(bond_table[atom]) &&                          # avoid duplication
           0.16 <= dis2 <= dcov2_map[{atom.element, other.element}] # avoid too short
          bond_table[atom] << other
          bond_table[other] << atom
        end
      end
    end

    # Remove bonds for atoms that could potentially be as cation (Mg2+,
    # K+ or metals) but only if the neighbors are over-valence or can
    # fulfill their valence by increasing the order of another bond
    cation_atoms.each do |atom|
      bond_table[atom].reject! do |other|
        neighbors = bond_table[other]
        over_valence = neighbors.size > (other.max_valence || Int32::MAX)
        can_increase_bond_order = neighbors.any? do |n|
          bond_table[n].size < (n.max_valence || Int32::MAX)
        end
        if over_valence || can_increase_bond_order
          bond_table[other].reject! &.==(atom)
        end
        over_valence || can_increase_bond_order
      end
    end

    # Remove extra bonds such that valence is correct
    bond_table.each do |atom, bonded_atoms|
      max_bonds = atom.element.max_bonds
      if bonded_atoms.size > max_bonds
        if cell = @structure.cell
          bonded_atoms.sort_by! { |other| Spatial.distance2(cell, atom, other) }
        else
          bonded_atoms.sort_by! { |other| Spatial.distance2(atom, other) }
        end
        bonded_atoms.each(within: max_bonds..) do |other|
          bond_table[other].delete atom
        end
        bonded_atoms.truncate(0, max_bonds) # keep shortest bonded_atoms
      end
    end

    bond_table.each do |atom, bonds|
      bonds.each do |other|
        atom.bonds.add other if atom.serial < other.serial # avoid duplication
      end
    end
  end

  private def detect_residues(atoms : AtomView) : Array(Array(MatchData))
    fragments = [] of Array(MatchData)
    atoms.each_fragment do |frag|
      detector = Detector.new frag
      matches = [] of MatchData
      matches.concat detector.matches
      detector.unmatched_atoms.each_fragment do |frag|
        matches << make_match(frag)
      end
      fragments << matches
    end

    polymers, other = fragments.partition &.size.>(1)
    other = other.flatten.sort_by!(&.reskind).group_by(&.reskind).values
    polymers.size + other.size <= MAX_CHAINS ? polymers + other : [fragments.flatten]
  end

  # Guesses the hybridization of *atoms* based on the average bond
  # angles. If an atom has only one bond, the hybridization is copied
  # from the bonded atom if it has multiple bonds, otherwise is set
  # based on the missing valence.
  #
  # The rules are taken from the OpenBabel's `PerceiveBondOrders` function.
  private def guess_hybridization(atoms : AtomView) : Hash(Atom, Int32)
    Hash(Atom, Int32).new(initial_capacity: atoms.size).tap do |hash|
      # atoms with multiple connectivity first, terminal (single-bonded) atoms last
      atoms.sort_by!(&.degree.-).each do |atom|
        if atom.degree > 1
          avg_bond_angle = atom.bonded_atoms.combinations(2).mean do |(b, c)|
            Spatial.angle b, atom, c
          end
          case {atom.element, avg_bond_angle}
          when {_, 155..}                then hash[atom] = 1
          when {_, 115..}                then hash[atom] = 2
          when {PeriodicTable::S, 105..} then hash[atom] = 2
          when {PeriodicTable::P, 105..} then hash[atom] = 2
          end
        else
          other = atom.bonded_atoms[0]
          if other_hybrid = hash[other]? # terminal atom (other have multiple bonds)
            hash[atom] = other_hybrid
          else # diatomic fragment (both atom and other have one bond only)
            missing_valence = Math.min atom.missing_valence, other.missing_valence
            hash[atom] = 4 - missing_valence.clamp(1..3)
          end
        end
      end
    end
  end

  private def has_topology? : Bool
    @structure.n_residues > 1 || @structure.each_residue.first.name != "UNK"
  end

  private def make_match(atoms : Enumerable(Atom)) : MatchData
    atom_map = Hash(String, Atom).new initial_capacity: atoms.size
    ele_index = Hash(Element, Int32).new default_value: 0
    atoms.each do |atom|
      name = "#{atom.element.symbol}#{ele_index[atom.element] += 1}"
      atom_map[name] = atom
    end
    MatchData.new("UNK", :other, atom_map)
  end
end
