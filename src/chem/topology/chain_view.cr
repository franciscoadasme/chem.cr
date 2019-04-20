module Chem
  struct ChainView
    include ArrayView(Chain)
    include AtomCollection
    include ResidueCollection

    def [](id : Char) : Chain
      self[id]? || raise IndexError.new
    end

    def []?(id : Char) : Chain?
      find &.id.==(id)
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
  end
end
