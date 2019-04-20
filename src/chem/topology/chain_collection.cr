module Chem
  module ChainCollection
    abstract def each_chain : Iterator(Chain)
    abstract def each_chain(&block : Chain ->)

    def chains : ChainView
      chains = [] of Chain
      each_chain { |chain| chains << chain }
      ChainView.new chains
    end
  end
end
