require "./core_ext/iterator"
require "./topology"

module Chem
  class System
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Protein::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    def <<(chain : Chain)
      @chains << chain
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

    def each_chain : Iterator(Chain)
      @chains.each
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end

    def make_chain(**options) : Chain
      options = options.merge({system: self})
      chain = Chain.new **options
      self << chain
      chain
    end

    def size : Int32
      each_atom.sum(0) { 1 }
    end
  end
end
