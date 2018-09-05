require "../bias"
require "../periodic_table/element"
require "../geometry/vector"

module Chem
  # TODO rename `charge` to `formal_charge`
  # TODO add `partial_charge : Float64 = 0.0`
  # TODO add `residue_index` that starts from 0 and does not reset per chain
  class Atom
    property altloc : Char?
    property chain : Char?
    property charge : Int32 = 0
    property constraint : Constraint?
    property coords : Geometry::Vector
    property element : PeriodicTable::Element
    property index : Int32
    property insertion_code : Char?
    property name : String
    property occupancy : Float64 = 1
    property residue_name : String = "UNK"
    property residue_number : Int32 = 1
    property serial : Int32
    property temperature_factor : Float64 = 0

    delegate x, y, z, to: @coords

    def initialize(@index : Int32,
                   @name : String,
                   @element : Element,
                   @coords : Geometry::Vector)
      @serial = @index + 1
    end

    def self.dummy(index : Int32, at coords : Geometry::Vector) : self
      new index, "X", PeriodicTable::Element.new(0, "X", "X", mass: 0), coords
    end
  end
end
