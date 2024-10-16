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
      each { |atom| chains << atom.chain }
      ChainView.new chains.to_a
    end

    def coords : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new self
    end

    # Sets the atom coordinates.
    def coords=(coords : Enumerable(Spatial::Vec3)) : Enumerable(Spatial::Vec3)
      zip(coords) do |atom, vec|
        atom.coords = vec
      end
      coords
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
      each { |atom| residues << atom.residue }
      ResidueView.new residues.to_a
    end
  end
end
