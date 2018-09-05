require "./core_ext/number"
require "./geometry/size3d"
require "./geometry/vector"

module Chem
  struct Lattice
    # @a : Float64
    # @b : Float64
    # @c : Float64
    # @scale_factor : Float64 = 1.0
    # @alpha : Float64
    # @beta : Float64
    # @gamma : Float64
    # @space_group : String
    # @z : Int32
    getter a : Geometry::Vector
    getter b : Geometry::Vector
    getter c : Geometry::Vector
    getter scale_factor : Float64 = 1.0
    getter space_group : String?

    def initialize(@a : Geometry::Vector,
                   @b : Geometry::Vector,
                   @c : Geometry::Vector,
                   @scale_factor : Float64 = 1.0,
                   @space_group : String? = nil)
    end

    def initialize(size : {Float64, Float64, Float64},
                   angles : {Float64, Float64, Float64},
                   @space_group : String? = nil)
      cos_alpha = Math.cos angles[0].radians
      cos_beta = Math.cos angles[1].radians
      cos_gamma = Math.cos angles[2].radians
      sin_gamma = Math.sin angles[2].radians

      cx = size[2] * cos_beta
      cy = size[2] * (cos_alpha - cos_beta * cos_gamma) / sin_gamma
      cz = Math.sqrt size[2]**2 - cx**2 - cy**2

      @a = Geometry::Vector[size[0], 0, 0]
      @b = Geometry::Vector[size[1] * cos_gamma, size[1] * sin_gamma, 0]
      @c = Geometry::Vector[cx, cy, cz]
    end

    def self.[](a : Float64, b : Float64, c : Float64)
      orthorombic a, b, c
    end

    def self.orthorombic(a : Float64,
                         b : Float64,
                         c : Float64,
                         scale_factor : Float64 = 1.0)
      new Geometry::Vector[a, 0, 0],
        Geometry::Vector[0, b, 0],
        Geometry::Vector[0, 0, c],
        scale_factor,
        "P 1"
    end

    def alpha : Float64
      @b.angle @c
    end

    def beta : Float64
      @a.angle c
    end

    def gamma : Float64
      @a.angle @b
    end

    def size : Geometry::Size3D
      Geometry::Size3D.new @a.magnitude, @b.magnitude, @c.magnitude
    end
  end
end
