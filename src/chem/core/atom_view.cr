module Chem
  struct AtomView
    include Array::Wrapper(Atom)

    def bonds : Array(Bond)
      # TODO: use sorted set
      # FIXME: return bonds only to the atoms within this view
      bonds = Set(Bond).new
      each { |atom| bonds.concat atom.bonds }
      bonds.to_a
    end

    def chains : ChainView
      chains = Set(Chain).new
      each { |atom| atom.chain?.try { |chain| chains << chain } }
      ChainView.new chains.to_a
    end

    def pos : Spatial::Positions3Proxy
      Spatial::Positions3Proxy.new self
    end

    # Returns a new view whose atoms are permuted so that known
    # symmetric atoms best match *other*.
    #
    # Pairing is by index: *other* is the reference and is never
    # reordered. Only atoms in `self` are swapped. Symmetric atoms are
    # those listed in a residue template's `symmetric_atom_groups`. Each
    # group is a 2-fold interchange that must be applied all at once
    # (e.g. phenylalanine CD1↔CD2 together with CE1↔CE2). Independent
    # groups are enumerated locally per residue.
    #
    # For each residue that contributes atoms to both views, every
    # combination of its applicable groups is scored by the minimized
    # (fit) RMSD of that residue's selected atoms, using in-place RMSD
    # as a tiebreaker. The winning permutation is then used for the
    # global atom order. Residues without a template, without symmetry,
    # or whose symmetric atoms are missing from the view are skipped.
    # Atoms without a parent residue are left unchanged.
    #
    # Raises `ArgumentError` if the two views have different sizes.
    def sort_by_symmetry(to other : self) : self
      raise ArgumentError.new("Incompatible coordinates") if size != other.size

      ordered = to_a
      indices_by_residue = {} of Residue => Array(Int32)
      ordered.each_with_index do |atom, i|
        if residue = atom.residue?
          (indices_by_residue[residue] ||= [] of Int32) << i
        end
      end

      indices_by_residue.each do |residue, indices|
        next unless groups = residue.template.try(&.symmetric_atom_groups)

        name_to_index = {} of String => Int32
        indices.each do |i|
          if name = ordered[i].name?
            name_to_index[name] = i
          end
        end

        applicable = [] of Array(Tuple(Int32, Int32))
        groups.each do |pairs|
          swaps = [] of Tuple(Int32, Int32)
          pairs.each do |a, b|
            if (ia = name_to_index[a]?) && (ib = name_to_index[b]?)
              swaps << {ia, ib}
            end
          end
          applicable << swaps unless swaps.empty?
        end
        next if applicable.empty?

        local_index = {} of Int32 => Int32
        indices.each_with_index { |gi, li| local_index[gi] = li }
        local_groups = applicable.map do |pairs|
          pairs.map { |i, j| {local_index[i], local_index[j]} }
        end

        ref_local = indices.map { |i| other.unsafe_fetch(i).pos }
        local_pos = indices.map { |i| ordered[i].pos }
        n = local_groups.size
        best_mask = (0...(1 << n)).min_by do |mask|
          candidate = local_pos.dup
          swap_symmetric_groups(candidate, local_groups, mask)
          fit = candidate.size >= 3 ? Spatial.rmsd(candidate, ref_local, minimize: true) : 0.0
          inplace = Spatial.rmsd(candidate, ref_local, minimize: false)
          {fit, inplace}
        end
        swap_symmetric_groups(ordered, applicable, best_mask)
      end

      self.class.new(ordered)
    end

    # Returns the RMSD in Å between the enclosed atoms and *other*.
    # Delegates to `Positions3Proxy#rmsd`.
    def rmsd(
      other : self,
      minimize : Bool = false,
      use_symmetry : Bool = false,
    ) : Float64
      pos.rmsd(other.pos, minimize: minimize, use_symmetry: use_symmetry)
    end

    # :ditto:
    def rmsd(
      other : self,
      weights : Indexable(Float64),
      minimize : Bool = false,
      use_symmetry : Bool = false,
    ) : Float64
      pos.rmsd(other.pos, weights, minimize: minimize, use_symmetry: use_symmetry)
    end

    # Applies the 2-fold swaps selected by *mask*. Each bit of *mask*
    # corresponds to one group in *groups* (bit 0 is the first group).
    private def swap_symmetric_groups(
      ary : Array,
      groups : Array(Array(Tuple(Int32, Int32))),
      mask : Int,
    ) : Nil
      groups.each_with_index do |pairs, g|
        pairs.each { |i, j| ary.swap(i, j) } if mask.bit(g) == 1
      end
    end

    # Sets the atom coordinates.
    def pos=(pos : Enumerable(Spatial::Vec3)) : Enumerable(Spatial::Vec3)
      zip(pos) do |atom, vec|
        atom.pos = vec
      end
      pos
    end

    def each_fragment(& : self ->) : Nil
      atoms = to_set
      each do |atom|
        next unless atom.in?(atoms)
        atoms.delete atom
        fragment = [atom]
        fragment.each do |a|
          a.each_bonded_atom do |b|
            next unless b.in?(atoms)
            fragment << b
            atoms.delete b
          end
        end
        yield self.class.new(fragment).sort_by(&.number)
      end
    end

    def fragments : Array(self)
      fragments = [] of self
      each_fragment { |fragment| fragments << fragment }
      fragments
    end

    def residues : ResidueView
      residues = Set(Residue).new
      each { |atom| atom.residue?.try { |residue| residues << residue } }
      ResidueView.new residues.to_a
    end

    # Returns a mutable copy of the enclosed atoms.
    def to_a : Array(Atom)
      @wrapped.dup
    end

    # Returns the enclosed array. Mutating it changes the view's source.
    def to_unsafe : Array(Atom)
      @wrapped
    end
  end
end
