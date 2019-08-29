module Chem::Spatial
  struct AffineTransform
    alias ScalingFactors = Tuple(Number::Primitive, Number::Primitive, Number::Primitive)

    def initialize
      @buffer = Pointer(Float64).malloc(16) do |index|
        i = index // 4
        j = index % 4
        i == j ? 1.0 : 0.0
      end
    end

    def self.build(&block : Pointer(Float64) ->) : self
      transform = AffineTransform.new
      yield transform.to_unsafe
      transform
    end

    # Returns the transformation that converts Cartesian coordinates to fractional
    # coordinates in terms of the unit cell vectors
    #
    # This is equivalent to the basis change from standard to the basis defined by the
    # lattice vectors, which is calculated as the inverse of the latter
    def self.cart_to_fractional(lattice : Lattice) : self
      a, b, c = lattice.a, lattice.b, lattice.c
      det = a.x * (b.y * c.z - b.z * c.y) -
            b.x * (a.y * c.z + c.y * a.z) +
            c.x * (a.y * b.z - b.y * a.z)
      inv_det = 1 / det
      AffineTransform.build do |buffer|
        buffer[0] = (b.y * c.z - b.z * c.y) * inv_det
        buffer[1] = (c.x * b.z - b.x * c.z) * inv_det
        buffer[2] = (b.x * c.y - c.x * b.y) * inv_det
        buffer[4] = (c.y * a.z - a.y * c.z) * inv_det
        buffer[5] = (a.x * c.z - c.x * a.z) * inv_det
        buffer[6] = (a.y * c.x - a.x * c.y) * inv_det
        buffer[8] = (a.y * b.z - a.z * b.y) * inv_det
        buffer[9] = (a.z * b.x - a.x * b.z) * inv_det
        buffer[10] = (a.x * b.y - a.y * b.x) * inv_det
      end
    end

    # Returns the transformation that converts Cartesian coordinates to fractional
    # coordinates in terms of the unit cell vectors
    #
    # This is equivalent to the basis change from the basis defined by the lattice
    # vectors to the standard basis, which is expressed by the matrix formed by the
    # column lattice vectors
    def self.fractional_to_cart(lattice : Lattice) : self
      AffineTransform.build do |buffer|
        {lattice.a, lattice.b, lattice.c}.each_with_index do |vec, j|
          3.times do |i|
            buffer[i * 4 + j] = vec[i]
          end
        end
      end
    end

    def self.scaling(by factor : Number) : self
      AffineTransform.build do |buffer|
        3.times { |i| buffer[i * 4 + i] = factor.to_f }
      end
    end

    def self.scaling(by factors : ScalingFactors) : self
      AffineTransform.build do |buffer|
        factors.each_with_index { |ele, i| buffer[i * 4 + i] = ele.to_f }
      end
    end

    def self.translation(by offset : Vector) : self
      AffineTransform.build do |buffer|
        3.times { |i| buffer[i * 4 + 3] = offset[i] }
      end
    end

    def *(rhs : self) : self
      AffineTransform.build do |buffer|
        buffer.map_with_index!(16) do |ele, index|
          i = index // 4
          j = index % 4
          (0..3).sum do |d|
            unsafe_fetch(i * 4 + d) * rhs.unsafe_fetch(d * 4 + j)
          end
        end
      end
    end

    def *(rhs : Vector) : Vector
      x = unsafe_fetch(0) * rhs.x + unsafe_fetch(1) * rhs.y +
          unsafe_fetch(2) * rhs.z + unsafe_fetch(3)
      y = unsafe_fetch(4) * rhs.x + unsafe_fetch(5) * rhs.y +
          unsafe_fetch(6) * rhs.z + unsafe_fetch(7)
      z = unsafe_fetch(8) * rhs.x + unsafe_fetch(9) * rhs.y +
          unsafe_fetch(10) * rhs.z + unsafe_fetch(11)
      Vector.new x, y, z
    end

    def ==(rhs : self) : Bool
      (0..15).all? { |i| unsafe_fetch(i) == rhs.unsafe_fetch(i) }
    end

    # Returns the determinant of the inner 3x3 rotation matrix
    def inner_det : Float64
      unsafe_fetch(0) * (unsafe_fetch(5) * unsafe_fetch(10) -
                         unsafe_fetch(9) * unsafe_fetch(6)) -
        unsafe_fetch(1) * (unsafe_fetch(4) * unsafe_fetch(10) +
                           unsafe_fetch(6) * unsafe_fetch(8)) +
        unsafe_fetch(2) * (unsafe_fetch(4) * unsafe_fetch(9) -
                           unsafe_fetch(5) * unsafe_fetch(8))
    end

    # Calculates the inverse of the inner 3x3 rotation matrix
    private def inner_inv(buffer : Pointer(Float64))
      inv_det = 1 / inner_det
      buffer[0] = (unsafe_fetch(5) * unsafe_fetch(10) -
                   unsafe_fetch(9) * unsafe_fetch(6)) * inv_det
      buffer[1] = (unsafe_fetch(2) * unsafe_fetch(9) -
                   unsafe_fetch(1) * unsafe_fetch(10)) * inv_det
      buffer[2] = (unsafe_fetch(1) * unsafe_fetch(6) -
                   unsafe_fetch(2) * unsafe_fetch(5)) * inv_det
      buffer[4] = (unsafe_fetch(6) * unsafe_fetch(8) -
                   unsafe_fetch(4) * unsafe_fetch(10)) * inv_det
      buffer[5] = (unsafe_fetch(0) * unsafe_fetch(10) -
                   unsafe_fetch(2) * unsafe_fetch(8)) * inv_det
      buffer[6] = (unsafe_fetch(4) * unsafe_fetch(2) -
                   unsafe_fetch(0) * unsafe_fetch(6)) * inv_det
      buffer[8] = (unsafe_fetch(4) * unsafe_fetch(9) -
                   unsafe_fetch(8) * unsafe_fetch(5)) * inv_det
      buffer[9] = (unsafe_fetch(8) * unsafe_fetch(1) -
                   unsafe_fetch(0) * unsafe_fetch(9)) * inv_det
      buffer[10] = (unsafe_fetch(0) * unsafe_fetch(5) -
                    unsafe_fetch(4) * unsafe_fetch(1)) * inv_det
    end

    def inspect(io : ::IO)
      io << "AffineTransform[["
      16.times do |index|
        i = index // 4
        j = index % 4
        io << (j == 0 ? "], [" : ", ") if i > 0 || j > 0
        unsafe_fetch(index).inspect io
      end
      io << "]]"
    end

    # Returns the inverse transformation
    #
    # The algorithm exploits the fact that when a matrix looks like this
    #
    # ```text
    # A = [ M   b  ]
    #     [ 0   1  ]
    # ```
    #
    # where A is 4x4 (augmented matrix), M is 3x3 (rotation matrix), b is 3x1
    # (translation vector), and the bottom row is (0, 0, 0, 1), then
    #
    # ```text
    # inv(A) = [ inv(M)   -inv(M) * b ]
    #          [   0            1     ]
    # ```
    #
    # `inv(M)` is computed following the standard procedure (see Wikipedia, Inversion of
    # 3x3 matrices).
    #
    # Refer to https://stackoverflow.com/a/2625420 or Wikipedia, Affine transformation
    # article (Properties section) for a detailed explanation.
    def inv : self
      AffineTransform.build do |buffer|
        inner_inv buffer
        {3, 7, 11}.each do |i|
          buffer[i] = (0..2).sum do |j|
            -buffer[i - 3 + j] * unsafe_fetch(j * 4 + 3)
          end
        end
      end
    end

    def scale(by factor : Number) : self
      scale by: {factor, factor, factor}
    end

    def scale(by factors : ScalingFactors) : self
      AffineTransform.build do |buffer|
        buffer.copy_from @buffer, 16
        buffer.map_with_index!(12) do |ele, i|
          buffer[i] *= factors[i // 4]
        end
      end
    end

    def to_unsafe : Pointer(Float64)
      @buffer
    end

    def to_a : Array(Float64)
      Array(Float64).build(16) do |buffer|
        buffer.copy_from @buffer, 16
        16
      end
    end

    def translate(by offset : Vector) : self
      AffineTransform.build do |buffer|
        buffer.copy_from @buffer, 16
        3.times do |i|
          buffer[(i + 1) * 4 - 1] += offset[i]
        end
      end
    end

    def unsafe_fetch(index : Int) : Float64
      to_unsafe[index]
    end
  end
end
