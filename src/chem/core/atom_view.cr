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
