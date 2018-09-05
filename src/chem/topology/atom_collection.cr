require "./atom"
require "./atom_view"

module Chem
  module AtomCollection
    @atoms : Array(Atom)

    def atoms : AtomView
      AtomView.new @atoms
    end

    def bounds : Geom::Cuboid
      raise NotImplementedError.new
    end

    def formal_charge : Int32
      formal_charges.sum
    end

    def formal_charges : Array(Int32)
      @atoms.map &.charge
    end
  end
end
