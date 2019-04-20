module Chem
  class Structure
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    @chain_table = {} of Char => Chain
    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Protein::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    delegate :[], :[]?, to: @chain_table

    def self.build(&block) : self
      builder = Structure::Builder.new
      with builder yield builder
      builder.build
    end

    protected def <<(chain : Chain)
      @chains << chain
      @chain_table[chain.id] = chain
    end

    def each_atom : Iterator(Atom)
      iterators = [] of Iterator(Atom)
      each_chain do |chain|
        chain.each_residue do |residue|
          iterators << residue.each_atom
        end
      end
      Iterator.chain iterators
    end

    def each_atom(&block : Atom ->)
      @chains.each do |chain|
        chain.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      @chains.each
    end

    def each_chain(&block : Chain ->)
      @chains.each do |chain|
        yield chain
      end
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end

    def each_residue(&block : Residue ->)
      @chains.each do |chain|
        chain.each_residue do |residue|
          yield residue
        end
      end
    end

    def empty?
      size == 0
    end

    def inspect(io : ::IO)
      to_s io
    end

    def size : Int32
      each_atom.sum(0) { 1 }
    end

    def to_s(io : ::IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << size << " atoms"
      io << ", " << residues.size << " residues" if residues.size > 1
      io << ", "
      io << "non-" unless @lattice
      io << "periodic>"
    end

    def wrap(around center : Spatial::Vector? = nil) : self
      if lattice = @lattice
        Spatial::PBC.wrap self, lattice, center || lattice.center
        self
      else
        raise Error.new "Cannot wrap a non-periodic structure"
      end
    end
  end
end
