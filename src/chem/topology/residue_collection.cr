require "../core_ext/iterator"
require "./atom_collection"

module Chem
  module ResidueCollection
    include AtomCollection

    abstract def each_residue : Iterator(Residue)

    def each_atom : Iterator(Atom)
      Iterator.chain each_residue.map(&.each_atom).to_a
    end

    def each_residue(&block : Residue ->)
      each_residue.each &block
    end

    def residues : Array(Residue)
      each_residue.to_a
    end

    def size : Int32
      each_residue.sum &.size
    end
  end
end
