module Chem::PeriodicTable
  class Element
    getter atomic_number : Int32
    getter name : String
    getter symbol : String
    getter mass : Float64
    getter valence : Int32

    def initialize(@atomic_number : Int32,
                   @name : String,
                   @symbol : String,
                   @mass : Float64,
                   @valence : Int32 = 0)
    end
  end
end
