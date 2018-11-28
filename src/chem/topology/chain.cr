module Chem
  class Chain
    include AtomCollection
    include ResidueCollection

    @residue_table = {} of Tuple(Int32, Char?) => Residue
    @residues = [] of Residue

    getter id : Char
    getter structure : Structure

    def initialize(@id : Char, @structure : Structure)
      @structure << self
    end

    protected def <<(residue : Residue)
      if prev_res = @residues.last?
        residue.previous = prev_res
        prev_res.next = residue
      end
      @residues << residue
      @residue_table[{residue.number, residue.insertion_code}] = residue
    end

    def [](number : Int32, insertion_code : Char? = nil) : Residue
      @residue_table[{number, insertion_code}]
    end

    def []?(number : Int32, insertion_code : Char? = nil) : Residue?
      @residue_table[{number, insertion_code}]?
    end

    def each_atom : Iterator(Atom)
      Iterator.chain each_residue.map(&.each_atom).to_a
    end

    def each_residue : Iterator(Residue)
      @residues.each
    end
  end
end
