module Chem
  struct ChainView
    include ArrayView(Chain)
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    def [](id : Char) : Chain
      self[id]? || raise IndexError.new
    end

    def []?(id : Char) : Chain?
      find &.id.==(id)
    end

    def chains : self
      self
    end

    def each_atom : Iterator(Atom)
      iterators = [] of Iterator(Atom)
      each do |chain|
        chain.each_residue do |residue|
          iterators << residue.each_atom
        end
      end
      Iterator.chain iterators
    end

    def each_atom(&block : Atom ->)
      each do |chain|
        chain.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      each
    end

    def each_chain(&block : Chain ->)
      each do |chain|
        yield chain
      end
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each.map(&.each_residue).to_a
    end

    def each_residue(&block : Residue ->)
      each do |chain|
        chain.each_residue do |residue|
          yield residue
        end
      end
    end

    def n_atoms : Int32
      sum &.n_atoms
    end

    def n_chains : Int32
      size
    end

    def n_residues : Int32
      sum &.n_residues
    end
  end
end
