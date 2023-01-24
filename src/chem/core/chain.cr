module Chem
  class Chain
    include AtomCollection
    include ResidueCollection

    @residue_table = {} of Tuple(Int32, Char?) => Residue
    @residues = [] of Residue

    getter id : Char
    getter top : Topology
    delegate structure, to: @top

    def initialize(@top : Topology, @id : Char)
      raise ArgumentError.new("Non-alphanumeric chain id") unless @id.ascii_alphanumeric?
      @top << self
    end

    protected def <<(residue : Residue) : self
      @residues << residue
      @residue_table[{residue.number, residue.insertion_code}] = residue
      self
    end

    # The comparison operator.
    #
    # Returns `-1`, `0` or `1` depending on whether `self` precedes
    # *rhs*, equals to *rhs* or comes after *rhs*. The comparison is
    # done based on chain identifier.
    #
    # ```
    # chains = Structure.read("peptide.pdb").chains
    #
    # chains[0] <=> chains[1] # => -1
    # chains[1] <=> chains[1] # => 0
    # chains[2] <=> chains[1] # => 1
    # ```
    def <=>(rhs : self) : Int32
      @id <=> rhs.id
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
      if residue
        resid = {residue.number, residue.insertion_code}
        @residue_table.delete(resid) if @residue_table[resid]?.same?(residue)
      end
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

    def polymer? : Bool
      @residues.any? &.polymer?
    end

    def n_atoms : Int32
      each_residue.map(&.n_atoms).sum
    end

    def n_residues : Int32
      @residues.size
    end

    # Renumber residues based on the order by the output value of the
    # block.
    def renumber_residues_by(& : Residue -> _) : Nil
      # FIXME: `residue.number` call reset_cache internally, which
      # re-orders the residues each iteration. Maybe add a boolean to
      # avoid resetting the cache while editing.
      @residues.sort_by { |residue| yield residue }
        .each_with_index do |residue, i|
          residue.number = i + 1
        end
      reset_cache
    end

    # Renumber residues based on bond information. Residue ordering is
    # computed based on the link bond if available.
    def renumber_residues_by_connectivity : Nil
      num = 0
      residues = @residues.to_set
      while residue = residues.find(&.pred?(strict: false, use_numbering: false).nil?) ||
                      residues.first?
        while residue && residue.in?(residues)
          residue.number = (num += 1)
          residues.delete residue
          residue = residue.succ?(strict: false, use_numbering: false) ||
                    residue.bonded_residues.find(&.in?(residues))
        end
      end
      reset_cache
    end

    # Returns the chain specification.
    #
    # Chain specification is a short string representation encoding
    # chain information including the id.
    def spec : String
      String.build do |io|
        spec io
      end
    end

    # Writes the chain specification to the given IO.
    #
    # Chain specification is a short string representation encoding
    # chain information including the id.
    def spec(io : IO) : Nil
      io << @id
    end

    def to_s(io : IO)
      io << '<' << {{@type.name.split("::").last}} << ' '
      spec io
      io << '>'
    end

    # Copies `self` into *top*. It calls `#copy_to` on each residue,
    # which in turn calls `Atom#copy_to`, if *recursive* is `true`.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(top : Topology, recursive : Bool = true) : self
      chain = Chain.new top, @id
      each_residue &.copy_to(chain) if recursive
      chain
    end

    def reset_cache : Nil
      @residues.sort!
      @residue_table.clear
      @residues.each do |residue|
        @residue_table[{residue.number, residue.insertion_code}] = residue
      end
    end
  end
end
