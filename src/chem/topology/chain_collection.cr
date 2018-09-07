require "../core_ext/iterator"
require "./residue_collection"

module Chem
  module ChainCollection
    include ResidueCollection

    abstract def each_chain : Iterator(Chain)

    def chains : Array(Chain)
      each_chain.to_a
    end

    def each_chain(&block : Chain ->)
      each_chain.each &block
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end
  end
end
