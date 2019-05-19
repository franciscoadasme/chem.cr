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

    protected def <<(residue : Residue) : self
      if prev_res = @residues.last?
        residue.previous = prev_res
        prev_res.next = residue
      end
      @residues << residue
      @residue_table[{residue.number, residue.insertion_code}] = residue
      self
    end

    def [](number : Int32, insertion_code : Char? = nil) : Residue
      @residue_table[{number, insertion_code}]
    end

    def []?(number : Int32, insertion_code : Char? = nil) : Residue?
      @residue_table[{number, insertion_code}]?
    end

    def delete(residue : Residue) : Residue?
      residue = @residues.delete residue
      @residue_table.delete({residue.number, residue.insertion_code}) if residue
      residue
    end

    def each_atom : Iterator(Atom)
      Iterator.chain each_residue.map(&.each_atom).to_a
    end

    def each_atom(&block : Atom ->)
      each_residue do |residue|
        residue.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_residue : Iterator(Residue)
      @residues.each
    end

    def each_residue(&block : Residue ->)
      @residues.each do |residue|
        yield residue
      end
    end

    def structure=(new_structure : Structure) : Structure
      @structure.delete self
      @structure = new_structure
      new_structure << self
    end

    protected def reset_cache : Nil
      @residue_table.clear
      @residues.sort_by! { |residue| {residue.number, (residue.insertion_code || ' ')} }
      @residues.each do |residue|
        @residue_table[{residue.number, residue.insertion_code}] = residue
      end
    end
  end
end
