module Chem
  class Lattice
    property a : Spatial::Vector
    property b : Spatial::Vector
    property c : Spatial::Vector
    property origin : Spatial::Vector

    def initialize(@a : Spatial::Vector,
                   @b : Spatial::Vector,
                   @c : Spatial::Vector,
                   @origin : Spatial::Vector = Spatial::Vector.origin)
    end

    def self.new(a : Float64,
                 b : Float64,
                 c : Float64,
                 alpha : Float64 = 90.0,
                 beta : Float64 = 90.0,
                 gamma : Float64 = 90.0,
                 origin : Spatial::Vector = Spatial::Vector.origin) : self
      if alpha == 90 && beta == 90 && gamma == 90
        a = Spatial::Vector[a, 0, 0]
        b = Spatial::Vector[0, b, 0]
        c = Spatial::Vector[0, 0, c]
      else
        cos_alpha = Math.cos alpha.radians
        cos_beta = Math.cos beta.radians
        cos_gamma = Math.cos gamma.radians
        sin_gamma = Math.sin gamma.radians

        cx = c * cos_beta
        cy = c * (cos_alpha - cos_beta * cos_gamma) / sin_gamma
        cz = Math.sqrt c**2 - cx**2 - cy**2

        a = Spatial::Vector[a, 0, 0]
        b = Spatial::Vector[b * cos_gamma, b * sin_gamma, 0]
        c = Spatial::Vector[cx, cy, cz]
      end
      new a, b, c, origin
    end

    def self.[](a : Float64, b : Float64, c : Float64) : self
      new a, b, c
    end

    {% for name in %w(a b c) %}
      def {{name.id}}=(new_size : Number) : Spatial::Vector
        self.{{name.id}} = @{{name.id}}.resize new_size
      end

      def {{name.id}}=(vec : Spatial::Vector) : Spatial::Vector
        @basis_transform = nil
        @{{name.id}} = vec
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

    def change_coords(vec : Spatial::Vector) : Spatial::Vector
      basis_transform * (vec - @origin)
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

    def revert_coords(vec : Spatial::Vector) : Spatial::Vector
      (vec.x * @a + vec.y * @b + vec.z * @c) + @origin
    end

    def tetragonal? : Bool
      a.size == b.size && b.size != c.size && cuboid?
    end

    def triclinic? : Bool
      !cuboid? && !monoclinic? && !hexagonal?
    end

    def size : Spatial::Size
      Spatial::Size.new @a.size, @b.size, @c.size
    end

    def volume : Float64
      @a.dot(@b.cross(@c))
    end

    # Returns the transformation that converts Cartesian coordinates to fractional
    # coordinates in terms of the unit cell vectors
    #
    # This is equivalent to the basis change from standard to the basis defined by the
    # lattice vectors, which is calculated as the inverse of the latter
    private def basis_transform : Spatial::AffineTransform
      @basis_transform ||= Spatial::AffineTransform.build do |buffer|
        det = @a.x * (@b.y * @c.z - @b.z * @c.y) -
              @b.x * (@a.y * @c.z + @c.y * @a.z) +
              @c.x * (@a.y * @b.z - @b.y * @a.z)
        inv_det = 1 / det
        buffer[0] = (@b.y * @c.z - @b.z * @c.y) * inv_det
        buffer[1] = (@c.x * @b.z - @b.x * @c.z) * inv_det
        buffer[2] = (@b.x * @c.y - @c.x * @b.y) * inv_det
        buffer[4] = (@c.y * @a.z - @a.y * @c.z) * inv_det
        buffer[5] = (@a.x * @c.z - @c.x * @a.z) * inv_det
        buffer[6] = (@a.y * @c.x - @a.x * @c.y) * inv_det
        buffer[8] = (@a.y * @b.z - @a.z * @b.y) * inv_det
        buffer[9] = (@a.z * @b.x - @a.x * @b.z) * inv_det
        buffer[10] = (@a.x * @b.y - @a.y * @b.x) * inv_det
      end
    end
  end
end
