module Chem::Spatial
  struct Vec3
    # The unit vector pointing towards the X axis. Shorthand for
    # `Vec3[1, 0, 0]`.
    X = Vec3[1, 0, 0]
    # The unit vector pointing towards the Y axis. Shorthand for
    # `Vec3[0, 1, 0]`.
    Y = Vec3[0, 1, 0]
    # The unit vector pointing towards the Z axis. Shorthand for
    # `Vec3[0, 0, 1]`.
    Z = Vec3[0, 0, 1]
    # The unit vector pointing towards the XY direction. Shorthand for
    # `Vec3[1, 1, 0].normalize`.
    XY = Vec3[1, 1, 0].normalize
    # The unit vector pointing towards the XZ direction. Shorthand for
    # `Vec3[1, 0, 1].normalize`.
    XZ = Vec3[1, 0, 1].normalize
    # The unit vector pointing towards the YZ direction. Shorthand for
    # `Vec3[0, 1, 1].normalize`.
    YZ = Vec3[0, 1, 1].normalize
    # The unit vector pointing towards the XYZ direction. Shorthand for
    # `Vec3[1, 1, 1].normalize`.
    XYZ = Vec3[1, 1, 1].normalize

    # The backward unit vector. Shorthand for `Vec3[0, 0, -1]` or `-Vec3::Z`.
    BACK = -Z
    # The downward unit vector. Shorthand for `Vec3[0, -1, 0]` or `-Vec3::Y`.
    DOWN = -Y
    # The forward unit vector. Shorthand for `Vec3[0, 0, 1]` or `Vec3::Z`.
    FORWARD = Z
    # The left unit vector. Shorthand for `Vec3[-1, 0, 0]` or `-Vec3::X`.
    LEFT = -X
    # The right unit vector. Shorthand for `Vec3[1, 0, 0]` or `Vec3::X`.
    RIGHT = X
    # The upward unit vector. Shorthand for `Vec3[0, 1, 0]` or `Vec3::Y`.
    UP = Y

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

    # Returns the unit vector pointing towards the given direction.
    def self.[](direction : Direction) : self
      new direction
    end

    # Returns the additive identity of this type. This is the zero
    # vector.
    def self.additive_identity : self
      zero
    end

    # Reads a vector from *io* in the given *format*. See also:
    # `IO#read_bytes`.
    def self.from_io(io : IO, format : IO::ByteFormat = IO::ByteFormat::SystemEndian) : self
      new io.read_bytes(Float64, format),
        io.read_bytes(Float64, format),
        io.read_bytes(Float64, format)
    end

    # Returns the unit vector pointing towards the given direction.
    def self.new(direction : Direction) : self
      case direction
      in .x?   then X
      in .y?   then Y
      in .z?   then Z
      in .xy?  then XY
      in .xz?  then XZ
      in .yz?  then YZ
      in .xyz? then XYZ
      end
    end

    # Returns a random vector with the elements within 0 and 1.
    def self.rand(random : Random = Random::DEFAULT) : self
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

    # Returns `true` if the elements of the vectors are close to each
    # other, else `false`. See the `#close_to` method.
    def =~(other : self) : Bool
      close_to?(other)
    end

    # Returns the absolute value (norm or length) of the vector.
    def abs : Float64
      Math.sqrt abs2
    end

    # Returns the square of the absolute value of the vector.
    def abs2 : Float64
      @x**2 + @y**2 + @z**2
    end

    # Returns `true` if the vector faces backward (-Z), else `false`.
    # See the `#faces?` method.
    def backward? : Bool
      faces? BACK
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

    # Returns `true` if the vector faces downward (-Y), else `false`.
    # See the `#faces?` method.
    def downward? : Bool
      faces? DOWN
    end

    # Returns `true` if the vector points towards the direction of
    # *other*, else `false`.
    #
    # ```
    # Vec3[1, 0, 0].faces?(Vec3[1, 0, 0])    # => true
    # Vec3[1, 2, 0].faces?(Vec3[1, 0, 0])    # => true
    # Vec3[1, 2, 3].faces?(Vec3[1, 0, 0])    # => true
    # Vec3[1, -2, -3].faces?(Vec3[1, 0, 0])  # => true
    # Vec3[-1, 0, 0].faces?(Vec3[1, 0, 0])   # => false
    # Vec3[-1, 2, 0].faces?(Vec3[1, 0, 0])   # => false
    # Vec3[-1, 2, 3].faces?(Vec3[1, 0, 0])   # => false
    # Vec3[-1, -2, -3].faces?(Vec3[1, 0, 0]) # => false
    # ```
    def faces?(other : self) : Bool
      dot(other).positive?
    end

    # Returns `true` if the vector points towards the given direction,
    # else `false`.
    #
    # ```
    # Vec3[1, 0, 0].faces?(:x)    # => true
    # Vec3[1, 2, 0].faces?(:x)    # => true
    # Vec3[1, 2, 3].faces?(:x)    # => true
    # Vec3[1, -2, -3].faces?(:x)  # => true
    # Vec3[-1, 0, 0].faces?(:x)   # => false
    # Vec3[-1, 2, 0].faces?(:x)   # => false
    # Vec3[-1, 2, 3].faces?(:x)   # => false
    # Vec3[-1, -2, -3].faces?(:x) # => false
    # ```
    def faces?(direction : Direction) : Bool
      faces? direction.to_vector
    end

    # Returns `true` if the vector faces forward (Z), else `false`. See
    # the `#faces?` method.
    def forward? : Bool
      faces? FORWARD
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

    # Returns the inverse of the vector. It is equivalent to the unary
    # negation operator.
    def inv : self
      -self
    end

    # Returns `true` if the vector faces left (-X), else `false`. See
    # the `#faces?` method.
    def leftward? : Bool
      faces? LEFT
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

    # Returns `true` if the vector is orthogonal to *other*, else
    # `false`.
    def orthogonal?(to other : self) : Bool
      dot(other) =~ 0
    end

    # Returns `true` if the vector is orthogonal to the given direction,
    # else `false`.
    def orthogonal?(to direction : Direction) : Bool
      orthogonal? direction.to_vector
    end

    # Returns a vector by increasing the length by *padding*.
    #
    # ```
    # Vec3[1, 0, 0].pad(2) # => Vec3[3, 0, 0]
    # a = Vec3[1, 2, 3]
    # a.abs                      # => 3.7416573867739413
    # b = a.pad(2)               # => Vec3[1.535, 3.069, 4.604]
    # b.abs                      # => 5.741657386773941
    # a.normalize =~ b.normalize # => true
    # ```
    def pad(padding : Number) : self
      resize abs + padding
    end

    # Returns `true` if the vector is parallel to *other*, else `false`.
    def parallel?(to other : self) : Bool
      dot(other)**2 =~ abs2 * other.abs2
    end

    # Returns `true` if the vector is parallel to the given direction,
    # else `false`.
    def parallel?(to direction : Direction) : Bool
      parallel? direction.to_vector
    end

    # Returns the projection of the vector on *vec*.
    def project(vec : self) : self
      vec = vec.normalize
      dot(vec) * vec
    end

    # Returns the projection of the vector onto the given direction.
    #
    # ```
    # Vec3[1, 2, 3].project(:y)  # => Vec3[ 0  2  0 ]
    # Vec3[1, 2, 3].project(:xz) # => Vec3[ 2  0  2 ]
    # ```
    def project(direction : Direction) : self
      project direction.to_vector
    end

    # Returns the rejection of the vector on *vec*.
    def reject(vec : self) : self
      self - project(vec)
    end

    # Returns the rejection of the vector onto the given direction.
    #
    # ```
    # Vec3[1, 2, 3].reject(:y)  # => Vec3[ 1  0  3 ]
    # Vec3[1, 2, 3].reject(:xz) # => Vec3[-1  2  1 ]
    # ```
    def reject(direction : Direction) : self
      reject direction.to_vector
    end

    # Returns a vector pointing in the same direction with the given
    # length.
    #
    # ```
    # a = Vec3[1, 2, 3]
    # a.abs                      # => 3.7416573867739413
    # b = a.resize 0.5           # => Vec3[0.134, 0.267, 0.401]
    # b.abs                      # => 0.5
    # b.normalize =~ a.normalize # => true
    # ```
    def resize(length : Number) : self
      return dup if zero?
      self * (length / abs)
    end

    # Returns `true` if the vector faces right (X), else `false`. See
    # the `#faces?` method.
    def rightward? : Bool
      faces? RIGHT
    end

    # Returns the vector rotated by the given Euler angles in degrees.
    # Delegates to `Quat.rotation` for computing the rotation.
    def rotate(x : Number, y : Number, z : Number) : self
      rotate Quat.rotation(x, y, z)
    end

    # Returns the vector rotated about *rotaxis* by *angle*
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(about rotaxis : Vec3, by angle : Number) : self
      rotate Quat.rotation(rotaxis, angle)
    end

    # Returns the vector rotated about the given direction by *angle*
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(about direction : Direction, by angle : Number) : self
      rotate direction.to_vector, angle
    end

    # Returns the vector rotated by the given quaternion.
    def rotate(quat : Quat) : self
      quat * self
    end

    # Returns an array with the components of the vector.
    #
    # ```
    # Vec3[1, 2, 3].to_a # => [1.0, 2.0, 3.0]
    # ```
    def to_a : Array(Float64)
      [@x, @y, @z]
    end

    # Writes the binary representation of the vector to *io* in the
    # given *format*. See also `IO#write_bytes`.
    def to_io(io : IO, format : IO::ByteFormat = :system_endian) : Nil
      @x.to_io io, format
      @y.to_io io, format
      @z.to_io io, format
    end

    def to_s(io : IO) : Nil
      io << "Vec3[ "
      {% for name, i in %w(x y z) %}
        {% if i > 0 %}
          io << (@{{name.id}} >= 0 ? "  " : ' ')
        {% end %}
        io.printf "%.{{PRINT_PRECISION}}g", @{{name.id}}
      {% end %}
      io << " ]"
    end

    # Returns the vector resulting of applying the given transformation.
    def transform(transformation : Transform) : self
      transformation * self
    end

    # Returns a new vector with the return value of the given block,
    # which is invoked with the X, Y, and Z components.
    #
    # ```
    # Vec3[3, 2, 1].transform do |x, y, z|
    #   x *= 2
    #   z /= 0.5
    #   {x, y, z}
    # end # => Vec3[6, 2, 2]
    # ```
    def transform(& : Float64, Float64, Float64 -> FloatTriple) : self
      components = yield @x, @y, @z
      self.class.new *components
    end

    # Returns the vector translated by the given offset.
    def translate(by offset : Vec3) : self
      self + offset
    end

    def unsafe_fetch(index : Int) : Float64
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else        Float64::NAN
      end
    end

    # Returns `true` if the vector faces upward (Y), else `false`. See
    # the `#faces?` method.
    def upward? : Bool
      faces? UP
    end

    # Returns the vector by wrapping into the primary unit cell. The
    # vector is assumed to be expressed in fractional coordinates.
    def wrap : self
      self - map { |ele| ele == 1 ? 0 : ele.floor }
    end

    # Returns the vector by wrapping into the primary unit cell centered
    # at *center*. The vector is assumed to be expressed in fractional
    # coordinates.
    def wrap(around center : self) : self
      offset = self - (center - Vec3[0.5, 0.5, 0.5])
      self - offset.map { |ele| ele == 1 ? 0 : ele.floor }
    end

    # Returns `true` if the vector is zero, else `false`.
    def zero? : Bool
      @x =~ 0 && @y =~ 0 && @z =~ 0
    end
  end
end
