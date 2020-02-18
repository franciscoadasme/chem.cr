module Chem
  struct AtomView
    include ArrayView(Atom)
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    def [](*, serial : Int) : Atom
      self[serial: serial]? || raise IndexError.new
    end

    def [](name : String) : Atom?
      self[name: name]? || raise KeyError.new
    end

    def []?(*, serial : Int) : Atom?
      find &.serial.==(serial)
    end

    def []?(name : String) : Atom?
      find &.name.==(name)
    end

    def atoms : self
      self
    end

    def each_atom : Iterator(Atom)
      each
    end

    def each_atom(&block : Atom ->)
      each do |atom|
        yield atom
      end
    end

    def each_chain : Iterator(Chain)
      each.map(&.chain).uniq
    end

    def each_chain(&block : Chain ->)
      each do |atom|
        yield if atom.chain == prev_chain
        prev_chain = atom.chain
      end
    end

    def each_residue : Iterator(Residue)
      each.map(&.residue).uniq
    end

    def each_residue(&block : Residue ->)
      residues = Set(Residue).new
      each do |atom|
        yield atom.residue unless residues.includes?(atom.residue)
        residues << atom.residue
      end
    end

    def n_atoms : Int32
      size
    end

    def n_chains : Int32
      each_chain.sum { 1 }
    end

    def n_residues : Int32
      each_residue.sum { 1 }
    end
  end
end
