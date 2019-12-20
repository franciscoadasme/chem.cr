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

    {% for op in ['+', '-', '*', '/'] %}
      def {{op.id}}(other : Number) : self
        Vector.new @x {{op.id}} other, @y {{op.id}} other, @z {{op.id}} other
      end

      def {{op.id}}(other : Vector) : self
        Vector.new @x {{op.id}} other.x, @y {{op.id}} other.y, @z {{op.id}} other.z
      end

      def {{op.id}}(other : Tuple(NumberType, NumberType, NumberType)) : self
        map_with_index { |value, i| value {{op.id}} other[i] }
      end
    {% end %}

    {% for op in %w(+ -) %}
      def {{op.id}}(rhs : Size) : self
        Vector.new @x {{op.id}} rhs.x, @y {{op.id}} rhs.y, @z {{op.id}} rhs.z
      end
    {% end %}

    def - : self
      inv
    end

    def *(rhs : AffineTransform) : self
      rhs * self
    end

    def abs : self
      map &.abs
    end

    def clamp(min : Number, max : Number) : self
      map &.clamp(min, max)
    end

    def clamp(range : Range) : self
      map &.clamp(range)
    end

    def cross(other : Vector) : self
      Vector.new @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
    end

    def dot(other : Vector) : Float64
      @x * other.x + @y * other.y + @z * other.z
    end

    def floor : self
      map &.floor
    end

    def inv : self
      Vector.new -@x, -@y, -@z
    end

    def inspect(io : ::IO)
      io << "Vector[" << @x << ", " << @y << ", " << @z << ']'
    end

    def map(&block : Float64 -> Number::Primitive) : self
      Vector.new (yield @x).to_f, (yield @y).to_f, (yield @z).to_f
    end

    def map_with_index(&block : Float64, Int32 -> Number::Primitive) : self
      Vector.new (yield @x, 0).to_f, (yield @y, 1).to_f, (yield @z, 2).to_f
    end

    def normalize : self
      resize 1
    end

    def origin? : Bool
      zero?
    end

    def pad(padding : Number) : self
      resize size + padding
    end

    def resize(new_size : Number) : self
      return dup if zero?
      self * (new_size / size)
    end

    def rotate(about rotaxis : Vector, by theta : Float64) : self
      Quaternion.rotation(rotaxis, theta).rotate self
    end

    def round : self
      map &.round
    end

    def size : Float64
      Math.sqrt @x**2 + @y**2 + @z**2
    end

    def to_a : Array(Float64)
      [x, y, z]
    end

    def to_m : Linalg::Matrix
      Linalg::Matrix.column @x, @y, @z
    end

    def to_cartesian(basis : Basis) : self
      @x * basis.i + @y * basis.j + @z * basis.k
    end

    def to_cartesian(lattice : Lattice) : self
      to_cartesian lattice.basis
    end

    def to_fractional(basis : Basis) : self
      basis.transform * self
    end

    def to_fractional(lattice : Lattice) : self
      to_fractional lattice.basis
    end

    def to_s(io : ::IO)
      io << '[' << @x << ' ' << @y << ' ' << @z << ']'
    end

    def to_t : Tuple(Float64, Float64, Float64)
      {x, y, z}
    end

    def wrap : self
      self - map_with_index { |ele, i| ele == 1 ? 0 : ele.floor }
    end

    def wrap(around center : self) : self
      offset = self - (center - Vector[0.5, 0.5, 0.5])
      self - offset.map_with_index { |ele, i| ele == 1 ? 0 : ele.floor }
    end

    def wrap(lattice : Lattice) : self
      to_fractional(lattice).wrap.to_cartesian lattice
    end

    def wrap(lattice : Lattice, around center : self) : self
      to_fractional(lattice).wrap(center.to_fractional(lattice)).to_cartesian lattice
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
