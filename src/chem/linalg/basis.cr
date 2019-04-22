module Chem::Linalg
  struct Basis
    getter i : Spatial::Vector
    getter j : Spatial::Vector
    getter k : Spatial::Vector

    def initialize(@i : Spatial::Vector, @j : Spatial::Vector, @k : Spatial::Vector)
    end

    def self.standard : self
      Basis.new Spatial::Vector.x, Spatial::Vector.y, Spatial::Vector.z
    end

    def standard? : Bool
      @i.x? && @j.y? && @k.z?
    end
  end
end
