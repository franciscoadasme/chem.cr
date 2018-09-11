module Chem
  struct ResidueView
    include ArrayView(Residue)
    include AtomCollection
    include ChainCollection

    def [](*, serial : Int) : Residue
      self[serial: serial]? || raise IndexError.new
    end

    def []?(*, serial : Int) : Residue?
      find &.number.==(serial)
    end

    def each_atom : Iterator(Atom)
      Iterator.chain map(&.each_atom)
    end

    def each_chain : Iterator(Chain)
      each.map(&.chain).uniq
    end
  end
end
