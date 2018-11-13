module Chem
  class Chain
    include AtomCollection
    include ResidueCollection

    @residues = [] of Residue

    getter identifier : Char?
    getter system : System

    def initialize(@identifier : Char?, @system : System)
      @system << self
    end

    protected def <<(residue : Residue)
      if prev_res = @residues.last?
        residue.previous = prev_res
        prev_res.next = residue
      end
      @residues << residue
    end

    def each_atom : Iterator(Atom)
      Iterator.chain each_residue.map(&.each_atom).to_a
    end

    def each_residue : Iterator(Residue)
      @residues.each
    end

    def id : Char?
      @identifier
    end
  end
end
