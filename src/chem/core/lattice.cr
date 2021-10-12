module Chem
  class Lattice
    getter basis : Spatial::Basis

    delegate a, alpha, b, beta, c, gamma, i, j, k, size, to: @basis

    def initialize(@basis : Spatial::Basis)
    end

    def self.new(*args, **options) : self
      new Spatial::Basis.new(*args, **options)
    end

    def *(value : Number) : self
      Lattice.new i * value, j * value, k * value
    end

    def a=(value : Float64) : Float64
      @basis = Spatial::Basis.new i.resize(value), j, k
      value
    end

    def b=(value : Float64) : Float64
      @basis = Spatial::Basis.new i, j.resize(value), k
      value
    end

    def bounds : Spatial::Bounds
      Spatial::Bounds.new Spatial::Vec3.origin, @basis
    end

    def c=(value : Float64) : Float64
      @basis = Spatial::Basis.new i, j, k.resize(value)
      value
    end

    def cubic? : Bool
      a == b && b == c && cuboid?
    end

    def cuboid? : Bool
      alpha == 90 && beta == 90 && gamma == 90
    end

    def hexagonal? : Bool
      a == b && alpha == 90 && beta == 90 && gamma == 120
    end

    def i=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Basis.new vec, j, k
      vec
    end

    def inspect(io : IO) : Nil
      io << "<Lattice "
      i.to_s io
      io << ", "
      j.to_s io
      io << ", "
      k.to_s io
      io << '>'
    end

    def j=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Basis.new i, vec, k
      vec
    end

    def k=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Basis.new i, j, vec
      vec
    end

    def monoclinic? : Bool
      a != c && alpha == 90 && beta != 90 && gamma == 90
    end

    def orthorhombic? : Bool
      a != b && a != c && b != c && cuboid?
    end

    def tetragonal? : Bool
      a == b && b != c && cuboid?
    end

    def triclinic? : Bool
      !cuboid? && !monoclinic? && !hexagonal?
    end
  end
end
