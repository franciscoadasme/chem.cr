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

    def transform(to other : Basis) : Spatial::AffineTransform
      if self == other
        Spatial::AffineTransform.new
      elsif other.standard?
        Spatial::AffineTransform.new to_m
      elsif standard?
        Spatial::AffineTransform.new other.to_m.inv
      else
        Spatial::AffineTransform.new other.to_m.inv * to_m
      end
    end

    def to_m : Matrix
      Matrix[
        [@i.x, @j.x, @k.x],
        [@i.y, @j.y, @k.y],
        [@i.z, @j.z, @k.z]]
    end
  end
end
