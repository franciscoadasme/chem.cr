module Chem::Spatial
  struct Vec3
    # X component of the vector.
    getter x : Float64
    # Y component of the vector.
    getter y : Float64
    # Z component of the vector.
    getter z : Float64

    # Creates a new vector representing the position (*x*, *y*, *z*).
    def initialize(@x : Float64, @y : Float64, @z : Float64)
    end

    # Returns a new vector representing the position (*x*, *y*, *z*).
    @[AlwaysInline]
    def self.[](x : Number, y : Number, z : Number) : self
      new x.to_f, y.to_f, z.to_f
    end

    # Returns a random vector with the elements within 0 and 1.
    def self.rand(random = Random::DEFAULT) : self
      Vec3[random.rand, random.rand, random.rand]
    end

    # Returns the zero vector.
    @[AlwaysInline]
    def self.zero : self
      Vec3[0, 0, 0]
    end

    # Returns the *i*th component of the vector in the XYZ order. Raises
    # `IndexError` if *index* is invalid.
    def [](index : Int32) : Float64
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else        raise IndexError.new
      end
    end

    {% begin %}
      {% op_map = {
           "+" => "addition",
           "-" => "subtraction",
           "*" => "multiplication",
           "/" => "division",
         } %}
      {% for op in %w(+ - * /) %}
        # Returns the element-wise {{op_map[op].id}} of the vector by
        # *rhs*.
        def {{op.id}}(rhs : Number) : self
          Vec3[@x {{op.id}} rhs, @y {{op.id}} rhs, @z {{op.id}} rhs]
        end

        # :ditto:
        def {{op.id}}(rhs : Vec3) : self
          Vec3[@x {{op.id}} rhs.x, @y {{op.id}} rhs.y, @z {{op.id}} rhs.z]
        end
      {% end %}

      {% for op in %w(+ -) %}
        # Returns the element-wise {{op_map[op].id}} of the vector by
        # *rhs*.
        def {{op.id}}(rhs : Size3) : self
          Vec3[@x {{op.id}} rhs[0], @y {{op.id}} rhs[1], @z {{op.id}} rhs[2]]
        end
      {% end %}
    {% end %}

    # Returns the negation of the vector.
    def - : self
      Vec3[-@x, -@y, -@z]
    end

    # Returns the absolute value (norm or length) of the vector.
    def abs : Float64
      Math.sqrt abs2
    end

    # Returns the square of the absolute value of the vector.
    def abs2 : Float64
      @x**2 + @y**2 + @z**2
    end

    # Returns `true` if the elements of the vectors are within *delta*
    # from each other, else `false`.
    #
    # ```
    # Vec3[1, 2, 3].close_to?(Vec3[1, 2, 3])                     # => true
    # Vec3[1, 2, 3].close_to?(Vec3[1.001, 1.999, 3.00004], 1e-3) # => true
    # Vec3[1, 2, 3].close_to?(Vec3[3, 2, 1])                     # => false
    # Vec3[1, 2, 3].close_to?(Vec3[1.001, 1.999, 3.00004], 1e-8) # => false
    # ```
    def close_to?(rhs : self, delta : Number = Float64::EPSILON) : Bool
      @x.close_to?(rhs.x, delta) &&
        @y.close_to?(rhs.y, delta) &&
        @z.close_to?(rhs.z, delta)
    end

    # Returns the cross product of the vector and *rhs*.
    def cross(rhs : Vec3) : self
      Vec3[
        @y * rhs.z - @z * rhs.y,
        @z * rhs.x - @x * rhs.z,
        @x * rhs.y - @y * rhs.x,
      ]
    end

    # Returns the dot product of the vector and *rhs*.
    def dot(rhs : Vec3) : Float64
      @x * rhs.x + @y * rhs.y + @z * rhs.z
    end

    # Returns vector's PBC image in fractional coordinates
    #
    # ```
    # vec = Vec3[0.456, 0.1, 0.8]
    # vec.image 1, 0, 0   # => Vec3[1.456, 0.1, 0.8]
    # vec.image -1, 0, 0  # => Vec3[-0.544, 0.1, 0.8]
    # vec.image -1, 1, -5 # => Vec3[-0.544, 1.1, -4.2]
    # ```
    def image(i : Int, j : Int, k : Int) : self
      self + Vec3[i, j, k]
    end

    # Returns vector's PBC image with respect to `lattice`
    #
    # ```
    # lat = Lattice.new S[2, 2, 3], 90, 90, 120
    # lat.i # => Vec3[2.0, 0.0, 0.0]
    # lat.j # => Vec3[-1, 1.732, 0.0]
    # lat.k # => Vec3[0.0, 0.0, 3.0]
    #
    # vec = Vec3[1, 1, 1.5]
    # vec.image(lat, 1, 0, 0) # => Vec3[3.0, 1.0, 1.5]
    # vec.image(lat, 0, 1, 0) # => Vec3[0.0, 2.732, 1.5]
    # vec.image(lat, 0, 0, 1) # => Vec3[1.0, 1.0, 4.5]
    # vec.image(lat, 1, 0, 1) # => Vec3[3.0, 1.0, 4.5]
    # vec.image(lat, 1, 1, 1) # => Vec3[2.0, 2.732, 4.5]
    # ```
    def image(lattice : Lattice, i : Int, j : Int, k : Int) : self
      self + lattice.i * i + lattice.j * j + lattice.k * k
    end

    # Returns the inverse of the vector. It is equivalent to the unary
    # negation operator.
    def inv : self
      -self
    end

    def inspect(io : IO)
      io << "Vec3[" << @x << ", " << @y << ", " << @z << ']'
    end

    # Returns a vector with the results of the component-wise mapping by
    # the given block. This is useful to perform non-standard
    # transformations.
    #
    # ```
    # Vec3[1, 2, 3].map(&.**(2)) # => Vec3[1.0, 4.0, 9.0]
    # ```
    def map(& : Float64 -> Number) : self
      Vec3[(yield @x), (yield @y), (yield @z)]
    end

    # Returns a vector with the results of the component-wise mapping by
    # the given block yielding both the value and index. This is useful
    # to perform non-standard transformations.
    #
    # ```
    # Vec3[1, 2, 3].map { |ele, i| ele * i } # => Vec3[0.0, 2.0, 6.0]
    # ```
    def map_with_index(& : Float64, Int32 -> Number) : self
      Vec3[(yield @x, 0), (yield @y, 1), (yield @z, 2)]
    end

    # Returns the unit vector pointing in the same direction of the
    # vector.
    #
    # ```
    # v = Vec3[2.5, 0, 0].normalize # => Vec[1.0, 0.0, 0.0]
    # v.abs                         # => 1.0
    # v = Vec3[1, 1, 1].normalize   # => Vec[0.577, 0.577, 0.577]
    # v.abs                         # => 1.0
    # ```
    def normalize : self
      resize 1
    end

    # Returns a vector by increasing the length by *padding*.
    #
    # ```
    # Vec3[1, 0, 0].pad(2) # => Vec3[3, 0, 0]
    # a = Vec3[1, 2, 3]
    # a.abs                             # => 3.7416573867739413
    # b = a.pad(2)                      # => Vec3[1.535, 3.069, 4.604]
    # b.abs                             # => 5.741657386773941
    # a.normalize.close_to? b.normalize # => true
    # ```
    def pad(padding : Number) : self
      resize abs + padding
    end

    # Returns the projection of the vector on *vec*.
    def proj(vec : self) : self
      vec = vec.normalize
      dot(vec) * vec
    end

    # Returns the projection of the vector on the plane perpendicular
    # to *normal*.
    def proj_plane(normal : self) : self
      self - proj(normal)
    end

    # Returns a vector pointing in the same direction with the given
    # length.
    #
    # ```
    # a = Vec3[1, 2, 3]
    # a.abs                              # => 3.7416573867739413
    # b = a.resize 0.5                   # => Vec3[0.134, 0.267, 0.401]
    # b.abs                              # => 0.5
    # b.normalize.close_to?(a.normalize) # => true
    # ```
    def resize(length : Number) : self
      return dup if zero?
      self * (length / abs)
    end

    # Rotates the vector about *rotaxis* by *theta* degrees.
    def rotate(about rotaxis : Vec3, by theta : Number) : self
      Quat.rotation(rotaxis, theta) * self
    end

    # Returns an array with the components of the vector.
    #
    # ```
    # Vec3[1, 2, 3].to_a # => [1.0, 2.0, 3.0]
    # ```
    def to_a : Array(Float64)
      [@x, @y, @z]
    end

    # Returns a vector in Cartesian coordinates relative to *basis*. The
    # vector is assumed to be expressed in fractional coordinates.
    def to_cartesian(basis : Basis) : self
      @x * basis.i + @y * basis.j + @z * basis.k
    end

    # Returns a vector in Cartesian coordinates relative to *lattice*.
    # The vector is assumed to be expressed in fractional coordinates.
    def to_cartesian(lattice : Lattice) : self
      to_cartesian lattice.basis
    end

    # Returns a vector in fractional coordinates relative to *basis*.
    # The vector is assumed to be expressed in Cartesian coordinates.
    def to_fractional(basis : Basis) : self
      basis.transform * self
    end

    # Returns a vector in fractional coordinates relative to *lattice*.
    # The vector is assumed to be expressed in Cartesian coordinates.
    def to_fractional(lattice : Lattice) : self
      to_fractional lattice.basis
    end

    def to_s(io : IO)
      io << '[' << @x << ' ' << @y << ' ' << @z << ']'
    end

    # Returns the vector resulting of applying the given transformation.
    def transform(transformation : AffineTransform) : self
      transformation * self
    end

    # :ditto:
    def transform(q : Quat) : self
      q * self
    end

    # Returns the vector by wrapping into the primary unit cell. The
    # vector is assumed to be expressed in fractional coordinates.
    def wrap : self
      self - map_with_index { |ele, i| ele == 1 ? 0 : ele.floor }
    end

    # Returns the vector by wrapping into the unit cell centered at
    # *center*. The vector is assumed to be expressed in fractional
    # coordinates.
    def wrap(around center : self) : self
      offset = self - (center - Vec3[0.5, 0.5, 0.5])
      self - offset.map_with_index { |ele, i| ele == 1 ? 0 : ele.floor }
    end

    # Returns the vector by wrapping into *lattice*. The vector is
    # assumed to be expressed in Cartesian coordinates.
    def wrap(lattice : Lattice) : self
      to_fractional(lattice).wrap.to_cartesian lattice
    end

    # Returns the vector by wrapping into *lattice* centered at
    # *center*. The vector is assumed to be expressed in Cartesian
    # coordinates.
    def wrap(lattice : Lattice, around center : self) : self
      to_fractional(lattice).wrap(center.to_fractional(lattice)).to_cartesian lattice
    end

    # Returns `true` if the vector lies along X axis, else `false`.
    def x? : Bool
      !@x.close_to?(0) && @y.close_to?(0) && @z.close_to?(0)
    end

    # Returns `true` if the vector lies in the XY-plane, else `false`.
    def xy? : Bool
      (!@x.close_to?(0) || !@y.close_to?(0)) && @z.close_to?(0)
    end

    # Returns `true` if the vector lies in the XZ-plane, else `false`.
    def xz? : Bool
      (!@x.close_to?(0) || !@z.close_to?(0)) && @y.close_to?(0)
    end

    # Returns `true` if the vector lies along Y axis, else `false`.
    def y? : Bool
      @x.close_to?(0) && !@y.close_to?(0) && @z.close_to?(0)
    end

    # Returns `true` if the vector lies in the YZ-plane, else `false`.
    def yz? : Bool
      @x.close_to?(0) && (!@y.close_to?(0) || !@z.close_to?(0))
    end

    # Returns `true` if the vector lies along Z axis, else `false`.
    def z? : Bool
      @x.close_to?(0) && @y.close_to?(0) && !@z.close_to?(0)
    end

    # Returns `true` if the vector is zero, else `false`.
    def zero? : Bool
      @x.close_to?(0) && @y.close_to?(0) && @z.close_to?(0)
    end
  end
end