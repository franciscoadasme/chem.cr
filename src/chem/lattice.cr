module Chem
  class Lattice
    # @a : Float64
    # @b : Float64
    # @c : Float64
    # @scale_factor : Float64 = 1.0
    # @alpha : Float64
    # @beta : Float64
    # @gamma : Float64
    # @space_group : String
    # @z : Int32
    property a : Spatial::Vector
    property b : Spatial::Vector
    property c : Spatial::Vector
    property scale_factor : Float64 = 1.0
    property space_group : String?

    def initialize(@a : Spatial::Vector,
                   @b : Spatial::Vector,
                   @c : Spatial::Vector,
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

      @a = Spatial::Vector[size[0], 0, 0]
      @b = Spatial::Vector[size[1] * cos_gamma, size[1] * sin_gamma, 0]
      @c = Spatial::Vector[cx, cy, cz]
    end

    def self.[](a : Float64, b : Float64, c : Float64) : self
      orthorombic a, b, c
    end

    def self.orthorombic(a : Float64,
                         b : Float64,
                         c : Float64,
                         scale_factor : Float64 = 1.0) : self
      new Spatial::Vector[a, 0, 0],
        Spatial::Vector[0, b, 0],
        Spatial::Vector[0, 0, c],
        scale_factor,
        "P 1"
    end

    {% for name in %w(a b c) %}
      def {{name.id}}=(new_size : Number)
        @{{name.id}} = @{{name.id}}.resize to: new_size
      end
    {% end %}

    def alpha : Float64
      Spatial.angle @b, @c
    end

    def beta : Float64
      Spatial.angle @a, @c
    end

    def center : Spatial::Vector
      (@a + @b + @c) * 0.5
    end

    def cubic? : Bool
      a.size == b.size && b.size == c.size && cuboid?
    end

    def cuboid? : Bool
      alpha == 90 && beta == 90 && gamma == 90
    end

    def gamma : Float64
      Spatial.angle @a, @b
    end

    def hexagonal? : Bool
      a.size == b.size && alpha == 90 && beta == 90 && gamma == 120
    end

    def monoclinic? : Bool
      a.size != c.size && alpha == 90 && beta != 90 && gamma == 90
    end

    def orthorhombic? : Bool
      a.size != b.size && a.size != c.size && b.size != c.size && cuboid?
    end

    def tetragonal? : Bool
      a.size == b.size && b.size != c.size && cuboid?
    end

    def triclinic? : Bool
      !cuboid? && !monoclinic? && !hexagonal?
    end

    def size : Spatial::Size3D
      Spatial::Size3D.new @a.size, @b.size, @c.size
    end
  end
end
