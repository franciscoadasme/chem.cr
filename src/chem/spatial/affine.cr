module Chem::Spatial
  class AffineTransform
    alias ScalingFactors = Tuple(Number::Primitive, Number::Primitive, Number::Primitive)

    @mat : Linalg::Matrix

    def initialize
      @mat = Linalg::Matrix.identity 4
    end

    def initialize(matrix : Linalg::Matrix)
      case matrix.dim
      when {3, 3}
        @mat = matrix.resize 4, 4
        @mat[3, 3] = 1
      when {4, 4}
        @mat = matrix.dup
      else
        raise Error.new "Invalid transformation matrix"
      end
    end

    def self.scaling(by factor : Number) : self
      scaling by: {factor, factor, factor}
    end

    def self.scaling(by factors : ScalingFactors) : self
      AffineTransform.new Linalg::Matrix.diagonal(factors[0], factors[1], factors[2], 1)
    end

    def self.translation(by offset : Vector) : self
      AffineTransform.new.translate! by: offset
    end

    def *(rhs : self) : self
      AffineTransform.new @mat * rhs.@mat
    end

    def *(rhs : Vector) : Vector
      x = @mat.unsafe_fetch(0) * rhs.x +
          @mat.unsafe_fetch(1) * rhs.y +
          @mat.unsafe_fetch(2) * rhs.z +
          @mat.unsafe_fetch(3)
      y = @mat.unsafe_fetch(4) * rhs.x +
          @mat.unsafe_fetch(5) * rhs.y +
          @mat.unsafe_fetch(6) * rhs.z +
          @mat.unsafe_fetch(7)
      z = @mat.unsafe_fetch(8) * rhs.x +
          @mat.unsafe_fetch(9) * rhs.y +
          @mat.unsafe_fetch(10) * rhs.z +
          @mat.unsafe_fetch(11)
      Vector.new x, y, z
    end

    def <<(rhs : self) : self
      @mat.each_with_index do |value, i, j|
        i *= 4
        @mat.to_unsafe[i + j] = rhs.@mat.unsafe_fetch(i) * @mat.unsafe_fetch(0, j) +
                                rhs.@mat.unsafe_fetch(i + 1) * @mat.unsafe_fetch(1, j) +
                                rhs.@mat.unsafe_fetch(i + 2) * @mat.unsafe_fetch(2, j) +
                                rhs.@mat.unsafe_fetch(i + 3) * @mat.unsafe_fetch(3, j)
      end
      self
    end

    def ==(rhs : self) : Bool
      @mat == rhs.@mat
    end

    def dup : self
      AffineTransform.new @mat.dup
    end

    def inv : self
      AffineTransform.new @mat.inv
    end

    def inspect(io : ::IO)
      io << "AffineTransform[["
      @mat.each_with_index do |value, i, j|
        io << (j == 0 ? "], [" : ", ") if i > 0 || j > 0
        value.inspect io
      end
      io << "]]"
    end

    def scale(by factor : Number) : self
      scale({factor, factor, factor})
    end

    def scale(by factors : ScalingFactors) : self
      dup.scale! factors
    end

    def scale!(by factor : Number) : self
      scale!({factor, factor, factor})
    end

    def scale!(by factors : ScalingFactors) : self
      {% for i in 0..11 %}
        @mat.to_unsafe[{{i}}] *= factors[{{i / 4}}]
      {% end %}
      self
    end

    def translate(by offset : Vector) : self
      dup.translate! offset
    end

    def translate!(by offset : Vector) : self
      @mat.to_unsafe[3] += offset.x
      @mat.to_unsafe[7] += offset.y
      @mat.to_unsafe[11] += offset.z
      self
    end
  end
end
