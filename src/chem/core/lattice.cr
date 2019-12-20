module Chem
  class Lattice
    getter basis : Spatial::Basis

    delegate a, alpha, b, beta, c, gamma, i, j, k, size, to: @basis

    def initialize(@basis : Spatial::Basis)
    end

    def self.new(*args, **options) : self
      new Spatial::Basis.new(*args, **options)
    end

    def a=(value : Float64) : Float64
      @basis = Basis.new i.resize(value), j, k
      value
    end

    def b=(value : Float64) : Float64
      @basis = Basis.new i, j.resize(value), k
      value
    end

    def c=(value : Float64) : Float64
      @basis = Basis.new i, j, k.resize(value)
      value
    end

    def center : Vector
      (@basis.i + @basis.j + @basis.k) * 0.5
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

    def i=(vec : Spatial::Vector) : Spatial::Vector
      @basis = Basis.new vec, j, k
      vec
    end

    def j=(vec : Spatial::Vector) : Spatial::Vector
      @basis = Basis.new i, vec, k
      vec
    end

    def k=(vec : Spatial::Vector) : Spatial::Vector
      @basis = Basis.new i, j, vec
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

    def volume : Float64
      @basis.i.dot @basis.j.cross(@basis.k)
    end
  end
end
