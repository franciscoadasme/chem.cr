module Chem
  struct AtomView
    include ArrayView(Atom)
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
      each do |atom|
        yield if atom.residue == prev_residue
        prev_residue = atom.residue
      end
    end
  end
end
