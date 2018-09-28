module Chem::PeriodicTable
  class Element
    getter atomic_number : Int32
    getter covalent_radius : Float64
    getter mass : Float64
    getter name : String
    getter symbol : String
    getter valence : Int32
    getter vdw_radius : Float64

    def initialize(@atomic_number : Int32,
                   @name : String,
                   @symbol : String,
                   *,
                   @mass : Float64,
                   @covalent_radius : Float64 = 1.5,
                   @valence : Int32 = 0,
                   vdw_radius : Float64? = nil)
      @vdw_radius = vdw_radius || @covalent_radius + 0.9
    end
  end
end
