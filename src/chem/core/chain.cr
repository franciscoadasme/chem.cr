module Chem
  class Chain
    include AtomCollection
    include ResidueCollection

    @residue_table = {} of Tuple(Int32, Char?) => Residue
    @residues = [] of Residue

    getter id : Char
    getter structure : Structure

    def initialize(@id : Char, @structure : Structure)
      raise ArgumentError.new("Non-alphanumeric chain id") unless @id.ascii_alphanumeric?
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

    def clear : self
      @residue_table.clear
      @residues.clear
      self
    end

    def delete(residue : Residue) : Residue?
      residue = @residues.delete residue
      @residue_table.delete({residue.number, residue.insertion_code}) if residue
      residue
    end

    def dig(number : Int32) : Residue
      self[number]
    end

    def dig(number : Int32, *subindexes)
      self[number].dig *subindexes
    end

    def dig(number : Int32, insertion_code : Char?) : Residue
      self[number, insertion_code]
    end

    def dig(number : Int32, insertion_code : Char?, *subindexes)
      self[number, insertion_code].dig *subindexes
    end

    def dig?(number : Int32) : Residue?
      self[number]?
    end

    def dig?(number : Int32, *subindexes)
      if residue = self[number]?
        residue.dig? *subindexes
      end
    end

    def dig?(number : Int32, insertion_code : Char?) : Residue?
      self[number, insertion_code]?
    end

    def dig?(number : Int32, insertion_code : Char?, *subindexes)
      if residue = self[number, insertion_code]?
        residue.dig? *subindexes
      end
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

    def inspect(io : ::IO) : Nil
      io << "<Chain " << @id << '>'
    end

    def polymer? : Bool
      @residues.any? &.polymer?
    end

    def n_atoms : Int32
      each_residue.map(&.n_atoms).sum
    end

    def n_residues : Int32
      @residues.size
    end

    def structure=(new_structure : Structure) : Structure
      @structure.delete self
      @structure = new_structure
      new_structure << self
    end

    # Copies `self` into *structure*
    # It calls `#copy_to` on each residue, which in turn calls `Atom#copy_to`.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(structure : Structure) : self
      chain = Chain.new @id, structure
      each_residue &.copy_to(chain)
      chain
    end

    def reset_cache : Nil
      @residue_table.clear
      @residues.sort_by! { |residue| {residue.number, (residue.insertion_code || ' ')} }
      @residues.each_with_index do |residue, i|
        residue.previous = @residues[i - 1]?
        residue.next = @residues[i + 1]?
        @residue_table[{residue.number, residue.insertion_code}] = residue
      end
      @residues.first?.try &.previous=(nil)
      @residues.last?.try &.next=(nil)
    end
  end
end
