require "../core_ext/iterator"
require "./atom_view"
require "./atom"

module Chem
  module AtomCollection
    abstract def each_atom : Iterator(Atom)
    abstract def size : Int32

    def atoms : AtomView
      AtomView.new each_atom.to_a
    end

    def bounds
      raise NotImplementedError.new
    end

    def each_atom(&block : Atom ->)
      each_atom.each &block
    end

    def formal_charge : Int32
      each_atom.sum &.charge
    end

    def formal_charges : Array(Int32)
      each_atom.map(&.charge).to_a
    end
  end
end
