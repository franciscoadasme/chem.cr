module Chem::Spatial
  struct Vector
    private alias NumberType = Number::Primitive

    getter norm : Float64 { Math.sqrt @x**2 + @y**2 + @z**2 }
    getter x : Float64
    getter y : Float64
    getter z : Float64

    def self.[](x : NumberType, y : NumberType, z : NumberType) : self
      new x, y, z
    end

    def self.origin : self
      zero
    end

    def self.x : self
      Vector.new 1, 0, 0
    end

    def self.y : self
      Vector.new 0, 1, 0
    end

    def self.z : self
      Vector.new 0, 0, 1
    end

    def self.zero : self
      new 0, 0, 0
    end

    def initialize(@x : Float64, @y : Float64, @z : Float64)
    end

    def initialize(x : NumberType, y : NumberType, z : NumberType)
      @x = x.to_f
      @y = y.to_f
      @z = z.to_f
    end

    def [](index : Int32) : Float64
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else
        raise IndexError.new
      end
    end

    {% for op in ['+', '-'] %}
      def {{op.id}}(other : Vector) : self
        Vector.new @x {{op.id}} other.x, @y {{op.id}} other.y, @z {{op.id}} other.z
      end

      def {{op.id}}(other : {NumberType, NumberType, NumberType}) : self
        Vector.new @x {{op.id}} other[0], @y {{op.id}} other[1], @z {{op.id}} other[2]
      end

      def {{op.id}}(other : Size3D) : self
        Vector.new @x {{op.id}} other.a, @y {{op.id}} other.b, @z {{op.id}} other.c
      end
    {% end %}

    def - : self
      inv
    end

    {% for op in ['*', '/'] %}
      def {{op.id}}(other : NumberType) : self
        Vector.new @x {{op.id}} other, @y {{op.id}} other, @z {{op.id}} other
      end
    {% end %}

    def *(rhs : AffineTransform) : self
      rhs * self
    end

    def cross(other : Vector) : self
      Vector.new @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
    end

    def dot(other : Vector) : Float64
      @x * other.x + @y * other.y + @z * other.z
    end

    def inv : self
      Vector.new -@x, -@y, -@z
    end

    def normalize : self
      resize to: 1
    end

    def origin? : Bool
      zero?
    end

    def resize(*, by padding : Number) : self
      resize to: size + padding
    end

    def resize(*, to new_size : Number) : self
      return dup if zero?
      self * new_size / size
    end

    def rotate(about rotaxis : Vector, by theta : Float64) : self
      Quaternion.rotation(rotaxis, theta).rotate self
    end

    def size : Float64
      norm
    end

    def to_a : Array(Float64)
      [x, y, z]
    end

    def to_m : Linalg::Matrix
      Linalg::Matrix.column @x, @y, @z
    end

    def to_t : Tuple(Float64, Float64, Float64)
      {x, y, z}
    end

    def x? : Bool
      @x == 1 && @y == 0 && @z == 0
    end

    def y? : Bool
      @x == 0 && @y == 1 && @z == 0
    end

    def z? : Bool
      @x == 0 && @y == 0 && @z == 1
    end

    def zero? : Bool
      @x == 0 && @y == 0 && @z == 0
    end
  end
end
