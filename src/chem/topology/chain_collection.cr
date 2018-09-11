module Chem
  module ChainCollection
    abstract def each_chain : Iterator(Chain)

    def chains : ChainView
      ChainView.new each_chain.to_a
    end

    def each_chain(&block : Chain ->)
      each_chain.each &block
    end
  end
end
