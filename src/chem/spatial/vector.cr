require "../core_ext/number"

module Chem::Spatial
  struct Vector
    private alias NumberType = Number::Primitive

    getter x : Float64
    getter y : Float64
    getter z : Float64

    def self.[](x : NumberType, y : NumberType, z : NumberType) : self
      new x, y, z
    end

    def self.origin : self
      zero
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
    {% end %}

    def - : self
      inverse
    end

    {% for op in ['*', '/'] %}
      def {{op.id}}(other : NumberType) : self
        Vector.new @x {{op.id}} other, @y {{op.id}} other, @z {{op.id}} other
      end
    {% end %}

    def cross(other : Vector) : self
      Vector.new @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
    end

    def dot(other : Vector) : Float64
      @x * other.x + @y * other.y + @z * other.z
    end

    def inverse : self
      Vector.new -@x, -@y, -@z
    end

    def magnitude : Float64
      Math.sqrt @x**2 + @y**2 + @z**2
    end

    def normalize : self
      return dup if zero?
      self / magnitude
    end

    def origin? : Bool
      zero?
    end

    def to_a : Array(Float64)
      [x, y, z]
    end

    def to_t : Tuple(Float64, Float64, Float64)
      {x, y, z}
    end

    def zero? : Bool
      @x == 0 && @y == 0 && @z == 0
    end
  end
end
