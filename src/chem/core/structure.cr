module Chem
  class Structure
    MAX_CHAINS     = 62 # chain id is alphanumeric: A-Z, a-z or 0-9
    MIN_RING_ANGLE = 50 # angle cutoff to detect high ring strain

    getter biases = [] of Chem::Bias
    property experiment : Structure::Experiment?
    property! cell : Spatial::Parallelepiped?
    getter source_file : Path?
    property title : String = ""
    # Hash-like container that stores the structure's properties as key
    # (string)-value pairs. A property's value can be any of the
    # primitive types (string, integer, float, or bool), and so it's
    # internally stored as `Metadata::Any`. Use the cast methods
    # (`#as_*`) to convert to the desired type.
    #
    # ```
    # structure.metadata["foo"] = 123
    # structure.metadata["foo"]      # => Metadata::Any(123)
    # structure.metadata["foo"].as_i # => 123
    # structure.metadata["foo"].as_f # => 123.0
    # structure.metadata["foo"].as_s # raises TypeCastError
    # ```
    getter metadata = Metadata.new

    # Angles in the topology. See `Angle` for definition.
    setter angles = [] of Angle
    # Dihedral angles in the topology. See `Dihedral` for definition.
    setter dihedrals = [] of Dihedral
    # Improper dihedral angles in the topology. See `Improper` for
    # definition.
    setter impropers = [] of Improper

    @chain_table = {} of Char => Chain
    @chains = [] of Chain

    def initialize(source_file : Path | String | Nil = nil)
      source_file = Path.new(source_file) if source_file.is_a?(String)
      @source_file = source_file.try(&.expand)
    end

    def self.build(*args, **options, &) : self
      builder = Structure::Builder.new *args, **options
      with builder yield builder
      builder.build
    end

    def [](chain_id : Char) : Chain
      self[chain_id]? || raise KeyError.new
    end

    def []?(chain_id : Char) : Chain?
      @chain_table[chain_id]?
    end

    protected def <<(chain : Chain) : self
      @chains << chain
      @chain_table[chain.id] = chain
      self
    end

    # Returns the angles in the topology. See `Angle` for definition.
    def angles : Array::View(Angle)
      guess_angles if @angles.empty?
      @angles.view
    end

    # Assign bonds, formal charges, and residue's type from known residue
    # types.
    def apply_templates : Nil
      prev_res = nil
      residues.each do |residue|
        if template = residue.template
          residue.type = template.type
          residue.atoms.each do |atom|
            if atom_t = template[atom.name]?
              atom.formal_charge = atom_t.formal_charge
            end
          end

          template.bonds.each do |bond_t|
            if (lhs = residue[bond_t.atoms[0]]?) &&
               (rhs = residue[bond_t.atoms[1]]?) &&
               lhs.within_covalent_distance?(rhs)
              lhs.bonds.add rhs, bond_t.order
            end
          end

          if prev_res &&
             (bond_t = template.link_bond) &&
             (lhs = prev_res[bond_t.atoms[0]]?) &&
             (rhs = residue[bond_t.atoms[1]]?) &&
             lhs.within_covalent_distance?(rhs)
            lhs.bonds.add rhs, bond_t.order
          end
        end
        prev_res = residue
      end
    end

    def atoms : AtomView
      atoms = [] of Atom
      @chains.each do |chain|
        chain.residues.each do |residue|
          # #concat(Array) copies memory instead of appending one by one
          atoms.concat residue.atoms.to_a
        end
      end
      AtomView.new atoms
    end

    # Returns the bonds between all atoms.
    def bonds : Array(Bond)
      # TODO: use sorted set
      bonds = Set(Bond).new
      atoms.each { |atom| bonds.concat atom.bonds }
      bonds.to_a
    end

    # Returns the unit cell. Raises `Spatial::NotPeriodicError` if cell
    # is `nil`.
    def cell : Spatial::Parallelepiped
      @cell || raise Spatial::NotPeriodicError.new(
        "#{title || "Structure"} is not periodic")
    end

    def chains : ChainView
      ChainView.new @chains
    end

    def clear : self
      @chain_table.clear
      @chains.clear
      self
    end

    # Returns a deep copy of `self`, that is, every chain/residue/atom is copied.
    #
    # Unlike array-like classes in the language, `#dup` (shallow copy) is not possible.
    #
    # ```
    # structure = Structure.new "/path/to/file.pdb"
    # other = structure.clone
    # other == structure     # => true
    # other.same?(structure) # => false
    #
    # structure.dig('A', 23, "OG").partial_charge         # => 0.0
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # structure.dig('A', 23, "OG").partial_charge = 0.635 # => 0.635
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # ```
    def clone : self
      structure = Structure.new @source_file
      structure.biases.concat @biases
      structure.experiment = @experiment
      structure.cell = @cell
      structure.title = @title
      # TODO: drop copy_to and implement the nested loops here
      @chains.each &.copy_to(structure)
      bonds.each do |bond|
        a, b = bond.atoms
        a = structure.dig a.chain.id, a.residue.number, a.residue.insertion_code, a.name
        b = structure.dig b.chain.id, b.residue.number, b.residue.insertion_code, b.name
        a.bonds.add b, order: bond.order
      end
      structure
    end

    def pos : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new atoms, @cell
    end

    # Sets the atom coordinates.
    def pos=(pos : Enumerable(Spatial::Vec3)) : Enumerable(Spatial::Vec3)
      atoms.pos = pos
    end

    def delete(ch : Chain) : Chain?
      ch = @chains.delete ch
      @chain_table.delete(ch.id) if ch && @chain_table[ch.id]?.same?(ch)
      ch
    end

    def dig(id : Char) : Chain
      self[id]
    end

    def dig(id : Char, *subindexes)
      self[id].dig *subindexes
    end

    def dig?(id : Char) : Chain?
      self[id]?
    end

    def dig?(id : Char, *subindexes)
      if chain = self[id]?
        chain.dig? *subindexes
      end
    end

    # Returns the dihedral angles in the topology. See `Dihedral` for
    # definition.
    def dihedrals : Array::View(Dihedral)
      guess_dihedrals if @dihedrals.empty?
      @dihedrals.view
    end

    # Returns a new structure containing the selected atoms by the given
    # block.
    #
    # Structure properties such as biases, unit cell, title, etc. are
    # copied only if *copy_properties* is `true`.
    def extract(copy_properties : Bool = true, & : Atom -> Bool) : self
      structure = self.class.new(copy_properties ? @source_file : nil)
      atoms.each do |atom|
        next unless yield atom
        chain = structure.dig?(atom.chain.id) || atom.chain.copy_to(structure, recursive: false)
        residue = chain.dig?(atom.residue.number, atom.residue.insertion_code) ||
                  atom.residue.copy_to(chain, recursive: false)
        atom.copy_to residue
      end

      if copy_properties
        structure.biases.concat @biases
        structure.cell = @cell
        structure.experiment = @experiment
        structure.title = @title
      end
      structure
    end

    # TODO: implement compound accessors in a global module
    def formal_charge : Int32
      atoms.sum &.formal_charge
    end

    # Determines the angles based on connectivity. See `Angle` for
    # definition.
    #
    # NOTE: It deletes existing angles.
    def guess_angles : Nil
      @angles.clear
      atoms.each do |a2|
        a2.bonded_atoms.each_combination(2, reuse: true) do |(a1, a3)|
          @angles << Angle.new(a1, a2, a3)
        end
      end
    end

    # Determines the bonds from connectivity and geometry.
    #
    # Bonds are added when the pairwise distances are within the
    # corresponding covalent distances (see
    # `PeriodicTable.covalent_distance`). Bonds are added until the atoms'
    # valences are fulfilled. If extraneous bonds are found (beyond the
    # maximum number of bonds, see `Element#max_bonds`), the longest ones
    # will be removed.
    #
    # Bonds to atoms that could potential be as cations (K, Na, etc.) are
    # disfavored such that they won't be added if the neighbor is
    # over-valence or the bond can be substituted by increasing the bond
    # order of another bond of the neighbor (e.g., *C-O + K* is preferred
    # over *C-O-K* since *C-O* can be converted to *C=O*).
    #
    # Bond orders are assigned based on the following procedure. First,
    # atom hybridization is guessed from the geometry. Then, the bond
    # orders are determined such that both atoms must have the same
    # hybridization to assign a double (sp2) or triple (sp) bond. Bond
    # order is only changed if the bonded atoms have missing valence. If
    # multiple bonded atoms fulfill the requirements for increasing the
    # bond order, the atom with the most missing valence or that is
    # closest to the current atom is selected first. This procedure is
    # loosely based on OpenBabel's `PerceiveBondOrders` function.
    def guess_bonds(perceive_order : Bool = true) : Nil
      return if (atoms = self.atoms).empty?

      reset_connectivity

      # Setup existing bonds and cache some values
      bond_table = Hash(Atom, Array(Atom)).new
      dcov2_map = Hash({Element, Element}, Float64).new
      elements = Set(Element).new
      largest_atom = atoms.first
      cation_atoms = [] of Atom
      atoms.each do |atom|
        # Add existing bonds
        bond_table[atom] = Array(Atom).new(atom.element.max_bonds)

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

      # Add initial bonds based on pairwise distances
      kdtree = Spatial::KDTree.new(atoms.map(&.pos), cell?)
      atoms.each do |atom|
        cutoff = Math.sqrt(dcov2_map[{atom.element, largest_atom.element}])
        kdtree.each_neighbor(atom.pos, within: cutoff) do |index, dis2|
          other = atoms.unsafe_fetch(index)
          if atom.number < other.number &&                            # check bond once
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

      # Remove bonds that produce high ring strain (<50°) in distored structures
      bond_table.each do |atom, bonded_atoms|
        pb = atom.pos
        bonded_atoms.combinations(2).each do |(a, b)|
          pa = cell?.try(&.wrap(a.pos, around: pb)) || a.pos
          pc = cell?.try(&.wrap(b.pos, around: pb)) || b.pos
          next unless (pc - pb).angle(pa - pb).degrees < MIN_RING_ANGLE
          farther_atom = pa.distance(pb) > pc.distance(pb) ? a : b
          bonded_atoms.delete farther_atom
          bond_table[farther_atom].delete atom
        end
      end

      # Remove extra bonds such that valence is correct
      bond_table.each do |atom, bonded_atoms|
        max_bonds = atom.element.max_bonds
        if bonded_atoms.size > max_bonds
          if cell = cell?
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

      # Add detected bonds
      bond_table.each do |atom, bonds|
        bonds.each do |other|
          atom.bonds.add other if atom.number < other.number # avoid duplication
        end
      end

      # Perceive bond orders if requested
      if perceive_order
        # TODO: cache valences and missing valences in a hash to avoid
        # computing the valence each cycle
        hybridization_map = guess_hybridization
        atoms.select { |atom|
          atom.valence < (atom.max_valence || Int32::MAX) && hybridization_map[atom]?
        }
          .to_a
          .sort_by! { |atom| {atom.missing_valence, atom.degree, atom.number} }
          .each do |atom|
            next unless (missing_valence = atom.missing_valence) > 0
            atom.bonded_atoms
              .select! do |other|
                hybridization_map[other]? == hybridization_map[atom]? &&
                  other.valence < other.element.max_bonds
              end
              .sort_by! do |other|
                {
                  other.missing_valence,
                  other.degree,
                  other.bonded_atoms.count(&.heavy?),
                  atom.pos.distance2(other.pos),
                }
              end
              .each do |other|
                # prefer leave unsatisfied valence on terminal atoms
                next if !other.terminal? && other.missing_valence == 0

                case hybridization_map[other]
                when 2
                  atom.bonds[other].order = :double
                  missing_valence -= 1
                when 1
                  atom.bonds[other].order = :triple
                  missing_valence -= 2
                end
                break if missing_valence == 0
              end
          end

        # Increase valence of central atoms by increasing bond order to
        # bonded atoms only if it would lead to a complete valence (avoid
        # charged central atoms), e.g., SO4 would be S(-O)(-O)(-O)-O
        # without this (valence = 4), but it adds two double bonds to
        # achieve valence = 6. Adding a single double bond would not work
        # since it leads to an invalid valence = 5 (sulfur have valence of
        # 2, 4, or 6).
        conn_map = Hash(Atom, Array(Atom)).new { |hash, key| hash[key] = [] of Atom }
        atoms.reject(&.missing_valence.zero?).each do |atom|
          atom.bonded_atoms.each do |other|
            conn_map[other] << atom
          end
        end
        conn_map.each do |atom, bonded_atoms|
          new_valence = atom.valence + bonded_atoms.size
          target_valence = atom.element.target_valence new_valence
          next unless new_valence == target_valence &&
                      bonded_atoms.all? do |other|
                        hybridization_map[other]? == hybridization_map[atom]?
                      end
          bonded_atoms.each &.bonds[atom].order=(BondOrder::Double)
        end
      end
    end

    # Determines the dihedral angles based on connectivity. See `Dihedral`
    # for definition.
    #
    # NOTE: It deletes existing dihedral angles.
    def guess_dihedrals : Nil
      @dihedrals.clear
      # TODO: use a sorted set
      dihedrals = Set(Dihedral).new
      angles.each do |angle|
        a1, a2, a3 = angle.atoms
        a1.each_bonded_atom do |a0|
          next if a0 == a2 || a0 == a3
          dihedrals << Dihedral.new(a0, a1, a2, a3)
        end

        a3.each_bonded_atom do |a4|
          next if a4 == a2 || a4 == a1
          dihedrals << Dihedral.new(a1, a2, a3, a4)
        end
      end
      dihedrals.each { |dihedral| @dihedrals << dihedral }
    end

    # Returns the element of an atom based on its name. Raises `Error` if
    # the element could not be determined. Refer to `guess_element?` for
    # details.
    #
    # TODO: Move to `Chem` namespace
    def self.guess_element(atom_name : String) : Element
      guess_element?(atom_name) || raise Error.new("Could not guess element of #{atom_name}")
    end

    # Returns the element of an atom based on its name if possible, else
    # `nil`.
    #
    # This is a naive approach, where the first letter of *atom_name* is
    # tested first to get the element, then the name with trailing digits
    # stripped.
    #
    # TODO: Move to `Chem` namespace
    def self.guess_element?(atom_name : String) : Element?
      atom_name = atom_name.lstrip("123456789").capitalize
      PeriodicTable[atom_name[0]]? || PeriodicTable[atom_name]?
    end

    # Sets the formal charges based on the existing bonds.
    #
    # For most cases, the formal charge is calculated as
    #
    #     Nele - Tele + V
    #
    # where *Nele* is the number of valence electrons, *Tele* is the
    # number of electrons in the full valence shell, and *V* is the
    # effective valence, which is equivalent to the sum of the bond
    # orders. *Tele* is usually 8 following the octet rule, but there are
    # some exceptions (see `Element#target_electrons`).
    #
    # If an atom has no bonds, it is considered as a monoatomic ion, where
    # the formal charge is set according to the following rule: if the
    # valence electrons < 4 (cation, e.g., Na+, Mg2+), the formal charge
    # is equal to the number of valence electrons, else (anions, e.g.,
    # Cl-) it is equal to `Nele - Tele`.
    #
    # WARNING: Elements that have no valence determined such as transition
    # metals are ignored.
    def guess_formal_charges : Nil
      atoms.each do |atom|
        valence = atom.valence
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

    # Determines the improper dihedral angles based on connectivity. See
    # `Improper` for definition.
    #
    # Improper dihedral angles are often used to constraint the planarity
    # of certain functional groups of molecules in molecular mechanics
    # simulations, and so not every possible improper dihedral angle is
    # required. This method lists every possible improper dihedral angle
    # following the formal definition, which will probably generate
    # extraneous angles.
    #
    # NOTE: It deletes existing improper dihedral angles.
    def guess_impropers : Nil
      @impropers.clear
      # TODO: use a sorted set
      impropers = Set(Improper).new
      angles.each do |angle|
        a1, a2, a3 = angle.atoms
        a2.each_bonded_atom do |a4|
          impropers << Improper.new(a1, a2, a3, a4) unless a4.in?(a1, a3)
        end
      end
      impropers.each { |improper| @impropers << improper }
    end

    # Detects and assigns topology names from known residue templates based on
    # bond information.
    #
    # The method creates chains and residues according to the detected
    # fragments and residue matches. The procedure is as follows. First,
    # atoms are split into fragments, where each fragment is scanned for
    # matches to known residue templates. Then, fragments are divided into
    # polymer (e.g., peptide) and non-polymer (e.g., water) fragments
    # based on the number of residues per fragment. Non-polymer residues
    # are grouped together by their type (i.e., ion, solvent, etc.).
    # Finally, every polymer fragment and group of non-polymer fragments
    # are assigned to a unique chain and residues are created for each
    # match.
    #
    # NOTE: Fragments are assigned to a unique chain unless the chain
    # limit (62) is reached, otherwise all residues are assigned to the
    # same chain.
    #
    # WARNING: Existing chains and residues are invalid after calling this
    # method so do not cache them.
    def guess_names(registry : Templates::Registry = Templates::Registry.default) : Nil
      atoms = self.atoms.to_a
      clear

      matches, unmatched_atoms = Templates::Detector.new(atoms).detect registry

      chain = Chain.new self, 'A'
      resid = 0

      # Create residues from template matches
      matches.each do |match|
        # TODO: avoid triggering reset_cache internally when setting residue.chain
        residue = Residue.new(chain, (resid += 1), match.template.name)
        residue.type = match.template.type
        match.atom_map.each do |atom_t, atom|
          atom.name = atom_t.name
          # TODO: avoid triggering reset_cache internally when setting atom.residue
          atom.residue = residue
        end
      end

      # Create residues from unmatched atoms. Split them by connectivity
      # and assign a residue to each fragment.
      ele_index = Hash(Element, Int32).new(default_value: 0)
      unmatched_atoms.fragments.each do |atoms|
        residue = Residue.new(chain, (resid += 1), "UNK")
        atoms.each do |atom|
          atom.name = "#{atom.element.symbol.upcase}#{ele_index[atom.element] += 1}"
          # TODO: avoid triggering reset_cache internally when setting atom.residue
          atom.residue = residue
        end
        ele_index.clear
      end

      # Create groups to be transformed into chains
      fragments = chain.residues.residue_fragments
      polymers, nonpolymers = fragments.partition &.size.>(1)
      grouped_nonpolymers = nonpolymers.map(&.first).group_by(&.type).values
      if polymers.size + grouped_nonpolymers.size <= MAX_CHAINS
        clear
        (polymers + grouped_nonpolymers).each do |residues|
          chain = Chain.new self, next_chain_id(@chains.last?.try(&.id) || 'A'.pred)
          residues.each &.chain=(chain)
        end
      end

      renumber_residues_by_connectivity split_chains: false
      guess_unknown_residue_types
    end

    # Determines the atom hybridizations based on the average bond angles.
    #
    # The rules are taken from the OpenBabel's `PerceiveBondOrders`
    # function. If an atom has only one bond, the hybridization is copied
    # from the bonded atom if it has multiple bonds, otherwise is set
    # based on the missing valence.
    private def guess_hybridization : Hash(Atom, Int32)
      hybridation_map = Hash(Atom, Int32).new
      # atoms with multiple connectivity first, terminal (single-bonded) atoms last
      atoms.select(&.heavy?).to_a.sort_by!(&.degree.-).each do |atom|
        case atom.degree
        when 1
          other = atom.bonded_atoms[0]
          if hb = hybridation_map[other]? # terminal atom (other have multiple bonds)
            hybridation_map[atom] = hb
          else # diatomic fragment (both atom and other have one bond only)
            missing_valence = Math.min atom.missing_valence, other.missing_valence
            hybridation_map[atom] = 4 - missing_valence.clamp(1..3)
          end
        when 2..
          avg_bond_angle = atom.bonded_atoms.combinations(2).mean do |(b, c)|
            if cell = cell?
              Spatial.angle cell, b, atom, c
            else
              Spatial.angle b, atom, c
            end
          end
          case {atom.element, avg_bond_angle.round}
          when {_, 155..}                then hybridation_map[atom] = 1
          when {_, 115..}                then hybridation_map[atom] = 2
          when {PeriodicTable::N, 100..} then hybridation_map[atom] = 2 # 5-member aromatic ring
          when {PeriodicTable::S, 105..} then hybridation_map[atom] = 2
          when {PeriodicTable::P, 105..} then hybridation_map[atom] = 2
          end
        end
      end
      hybridation_map
    end

    # Determines the type of unknown residues based on their neighbors.
    def guess_unknown_residue_types : Nil
      # TODO: bond_t should be computed from bonded_residues
      return unless bond_t = residues.compact_map(&.template.try(&.link_bond)).first?
      residues.each do |residue|
        next if residue.template
        types = residue
          .bonded_residues(bond_t, forward_only: false, strict: false)
          .map(&.type)
          .uniq!
          .reject!(&.other?)
        residue.type = types.size == 1 ? types[0] : ResidueType::Other
      end
    end

    # Returns the improper dihedral angles in the topology. See `Improper`
    # for definition.
    def impropers : Array::View(Improper)
      guess_impropers if @impropers.empty?
      @impropers.view
    end

    def inspect(io : IO) : Nil
      to_s io
    end

    def periodic? : Bool
      !!@cell
    end

    # Renumber residues per chain based on the order by the output value
    # of the block.
    #
    # NOTE: This won't change the order of the existing chains.
    def renumber_residues_by(& : Residue -> _) : Nil
      @chains.each do |chain|
        chain.renumber_residues_by do |residue|
          yield residue
        end
      end
    end

    # Renumber chain and residues based on bond information.
    #
    # Residue fragments are assigned to unique chains unless
    # *split_chains* is `false`, which keeps existing chains intact.
    # Residue ordering is computed based on the link bond if available.
    #
    # NOTE: existing chains are reused to re-arrange the residues among
    # them, so avoid caching them before calling this.
    def renumber_residues_by_connectivity(split_chains : Bool = true) : Nil
      if split_chains
        id = 'A'.pred
        residues.residue_fragments.each do |residues|
          chain = dig?(id = id.succ) || Chain.new(self, id)
          chain.clear
          residues.each &.chain=(chain)
          chain.renumber_residues_by_connectivity
        end
      else
        @chains.each &.renumber_residues_by_connectivity
      end
    end

    protected def reset_cache : Nil
      @chain_table.clear
      @chains.sort_by! &.id
      @chains.each do |chain|
        @chain_table[chain.id] = chain
      end
    end

    # Deletes all bonds and resets formal charges to zero.
    def reset_connectivity : Nil
      # TODO: find a better way to reset bonds
      atoms.each do |atom|
        atom.bonds.each do |bond|
          atom.bonds.delete bond
        end
        atom.formal_charge = 0
      end
    end

    def residues : ResidueView
      residues = [] of Residue
      @chains.each do |chain|
        # #concat(Array) copies memory instead of appending one by one
        residues.concat chain.residues.to_a
      end
      ResidueView.new residues
    end

    def to_s(io : IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << atoms.size << " atoms"
      io << ", " << residues.size << " residues" if residues.size > 1
      io << ", "
      io << "non-" unless @cell
      io << "periodic>"
    end
  end
end

private def next_chain_id(ch : Char) : Char
  case ch
  when 'A'.pred
    'A'
  when 'A'..'Y', 'a'..'y', '0'..'8'
    ch.succ
  when 'Z'
    'a'
  when 'z'
    '0'
  else
    raise ArgumentError.new("No more chains available")
  end
end
