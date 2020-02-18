module Chem
  struct ResidueView
    include ArrayView(Residue)
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    def [](serial : Int, ins_code : Char) : Residue?
      self[serial, ins_code]? || raise IndexError.new
    end

    def [](*, serial : Int) : Residue
      self[serial: serial]? || raise IndexError.new
    end

    def []?(serial : Int, ins_code : Char) : Residue?
      find { |res| res.number == serial && res.insertion_code == ins_code }
    end

    def []?(*, serial : Int) : Residue?
      find &.number.==(serial)
    end

    def each_atom : Iterator(Atom)
      Iterator.chain map(&.each_atom)
    end

    def each_atom(&block : Atom ->)
      each do |residue|
        residue.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      each.map(&.chain).uniq
    end

    def each_chain(&block : Chain ->)
      chains = Set(Chain).new
      each do |residue|
        yield residue.chain unless chains.includes?(residue.chain)
        chains << residue.chain
      end
    end

    def each_residue : Iterator(Residue)
      each
    end

    def each_residue(&block : Residue ->)
      each do |residue|
        yield residue
      end
    end

    def n_atoms : Int32
      sum &.n_atoms
    end

    def n_chains : Int32
      each_chain.sum { 1 }
    end

    def n_residues : Int32
      size
    end

    def residues : self
      self
    end
  end
end
