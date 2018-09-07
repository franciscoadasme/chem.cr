require "./bias"
require "./lattice"
require "./protein/experiment"
require "./protein/sequence"
require "./topology/chain"
require "./topology/chain_collection"

module Chem
  class System
    include ChainCollection

    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Protein::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    def <<(chain : Chain)
      @chains << chain
    end

    def each_chain : Iterator(Chain)
      @chains.each
    end

    def make_chain(**options) : Chain
      options = options.merge({system: self})
      chain = Chain.new **options
      self << chain
      chain
    end
  end
end
