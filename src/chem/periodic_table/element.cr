module Chem::PeriodicTable
  class Element
    getter atomic_number : Int32
    getter covalent_radius : Float64
    getter mass : Float64
    getter name : String
    getter symbol : String
    getter valences : Array(Int32)
    getter vdw_radius : Float64

    def initialize(@atomic_number : Int32,
                   @name : String,
                   @symbol : String,
                   *,
                   @mass : Float64,
                   @covalent_radius : Float64 = 1.5,
                   @valences : Array(Int32) = [] of Int32,
                   vdw_radius : Float64? = nil)
      @vdw_radius = vdw_radius || @covalent_radius + 0.9
    end

    def max_valence : Int32
      @valences.last? || 0
    end
  end
end
