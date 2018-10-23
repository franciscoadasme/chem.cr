module Chem
  struct ResidueView
    include ArrayView(Residue)
    include AtomCollection
    include ChainCollection

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

    def each_chain : Iterator(Chain)
      each.map(&.chain).uniq
    end
  end
end
