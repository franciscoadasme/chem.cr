require "./atom"
require "./atom_view"

module Chem
  module AtomCollection
    abstract def each_atom(&block : Atom ->)
    abstract def size : Int32

    def atoms : AtomView
      ary = Array(Atom).new size
      each_atom { |atom| ary << atom }
      AtomView.new ary
    end

    def bounds
      raise NotImplementedError.new
    end

    def formal_charge : Int32
      formal_charges.sum
    end

    def formal_charges : Array(Int32)
      ary = [] of Int32
      each_atom { |atom| ary << atom.charge }
      ary
    end
  end
end
