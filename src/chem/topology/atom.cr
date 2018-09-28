require "../bias"
require "../periodic_table/element"
require "../geometry/vector"

module Chem
  # TODO rename `charge` to `formal_charge`
  # TODO add `partial_charge : Float64 = 0.0`
  # TODO add `residue_index` that starts from 0 and does not reset per chain
  class Atom
    getter bonds : BondArray { BondArray.new self }
    property charge : Int32 = 0
    property constraint : Constraint?
    property coords : Geometry::Vector
    property element : PeriodicTable::Element
    property index : Int32
    property name : String
    property occupancy : Float64 = 1
    property residue : Residue
    property serial : Int32
    property temperature_factor : Float64 = 0

    delegate x, y, z, to: @coords
    delegate chain, to: @residue

    def initialize(@name : String,
                   @index : Int32,
                   @coords : Geometry::Vector,
                   @residue : Residue,
                   element : PeriodicTable::Element? = nil,
                   @charge : Int32 = 0,
                   @occupancy : Float64 = 1,
                   @temperature_factor : Float64 = 0)
      @element = element || PeriodicTable[atom_name: @name]
      @serial = @index + 1
    end

    def bonded_atoms : Array(Atom)
      bonds.map &.other(self)
    end

    def valence : Int32
      @element.valence + @charge
    end
  end
end
