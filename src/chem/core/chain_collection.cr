module Chem
  module ChainCollection
    abstract def each_chain : Iterator(Chain)
    abstract def each_chain(&block : Chain ->)
    abstract def n_chains : Int32

    def chains : ChainView
      chains = Array(Chain).new n_chains
      each_chain { |chain| chains << chain }
      ChainView.new chains
    end
  end
end
