require "./residue_collection"

module Chem
  module ChainCollection
    include ResidueCollection

    abstract def each_chain(&block : Chain ->)

    def chains : Array(Chain)
      ary = Array(Chain).new
      each_chain { |chain| ary << chain }
      ary
    end

    def each_residue(&block : Residue ->)
      each_chain do |chain|
        chain.each_residue &block
      end
    end

    def size : Int32
      size = 0
      each_chain { |chain| size += chain.size }
      size
    end
  end
end
