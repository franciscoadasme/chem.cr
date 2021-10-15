module Chem::Spatial
  # The quaternion is a mathematical construct that extends the complex
  # numbers and it is useful to encode three-dimensional rotations.
  # Quaternions are represented by four numbers (w, x, y, z), where w is
  # considered as the real (scalar) part and x, y, z the imaginary
  # (vector) part. Rotations can be encoded as a unit quaternion using
  # the axis-angle representation, where x, y, z correspond to the
  # rotation axis and w to the rotation angle by the following formula:
  #
  # ```text
  # q(v, t) = q(w, x, y, z) = q(cos(t/2), sin(t/2)vx, sin(t/2)vy, sin(t/2)vz)
  # ```
  #
  # where *v* is a unit vector and *t* is the rotation angle.
  # Quaternions have several useful mathematical properties, e.g.,
  # quaternion multiplication can be used to represent a sequence of
  # rotations producing a single quaternion. Indeed, the rotation
  # encoded in the quaternion *q* can be applied to a ordinary vector
  # *p* simply by
  #
  # ```text
  # p* = q * p * q-1
  # ```
  #
  # where *q*-1 is the inverse of *q* and *p** is the rotated vector
  # (see `Quaternion#*` for details).
  #
  # ## Examples
  #
  # ```
  # q = Quaternion[1, 2, 3, 4]
  # q                 # => [1.0 2.0 3.0 4.0]
  # q.real            # => 1.0
  # q.imag            # => [2.0 3.0 4.0]
  # q.w               # => 1.0
  # q.x               # => 2.0
  # q.y               # => 3.0
  # q.z               # => 4.0
  # -q                # => [-1.0 -2.0 -3.0 -4.0]
  # q.abs             # => 5.477225575051661
  # q.abs2            # => 30.0
  # q.conj            # => [1.0 -2.0 -3.0 -4.0]
  # q.inv             # => [0.033 -0.067 -0.1 -0.133]
  # q.normalize       # => [0.183 0.365 0.548 0.730]
  # q.unit?           # => false
  # q.normalize.unit? # => true
  # q.zero?           # => false
  #
  # q * 2  # => [2.0 4.0 6.0 8.0]
  # q / 10 # => [0.2 0.4 0.6 0.8]
  #
  # p = Quaternion[4, 3, 2, 1]
  # p + q # => [5.0 5.0 5.0 5.0]
  # p * q # => [-12.0 16.0 4.0 22.0]
  # q * p # => [-12.0 6.0 24.0 12.0]
  # ```
  #
  # Use the convenience methods to encode rotations.
  #
  # ```
  # v = Vec3[1, 2, 3]
  # q = Quaternion.aligning v, to: Vec3[1, 0, 0]
  # q * v # => [3.742 0.0 0.0]
  # # or
  # v.transform(q)    # => [3.742 0.0 0.0]
  # (q * v).normalize # => [1.0 0.0 0.0]
  #
  # q = Quaternion.rotation Vec3[0, 1, 0], by: 90
  # q * v # => [3.0 2.0 -1.0]
  # v * q # => [-3.0 2.0 1.0]
  # ```
  #
  # NOTE: Quaternion multiplication is not commutative: `q * v != v *
  # p`, the former will apply the rotation encoded in *q* to *v* but the
  # latter will produce the inverse rotation. Use `Vec3#transform` to
  # avoid the ambiguity.
  struct Quaternion
    # Real (scalar) part of the quaternion.
    getter w : Float64
    # X component of the imaginary (vector) part of the quaternion.
    getter x : Float64
    # Y component of the imaginary (vector) part of the quaternion.
    getter y : Float64
    # Z component of the imaginary (vector) part of the quaternion.
    getter z : Float64

    # Creates a new quaternion with *w* as the real (scalar) part and
    # *x*, *y*, and *z* as the vector (imaginary) part.
    def initialize(@w : Float64, @x : Float64, @y : Float64, @z : Float64)
    end

    # Returns a quaternion with *w* as the real (scalar) part and *x*,
    # *y*, and *z* as the vector (imaginary) part.
    @[AlwaysInline]
    def self.[](w : Float64, x : Float64, y : Float64, z : Float64) : self
      Quaternion.new w, x, y, z
    end

    # Returns a quaternion encoding the rotation operation to align *v1*
    # to *v2*.
    def self.aligning(v1 : Vec3, to v2 : Vec3) : self
      Quaternion.rotation v1.cross(v2), Spatial.angle(v1, v2)
    end

    # Returns a quaternion encoding the rotation about the axis vector
    # *rotaxis* by *theta* degrees.
    def self.rotation(about rotaxis : Vec3, by theta : Float64) : self
      theta = theta.radians / 2
      vec = Math.sin(theta) * rotaxis.normalize
      Quaternion[Math.cos(theta), vec.x, vec.y, vec.z]
    end

    # Returns the element-wise addition of the quaternion by *rhs*.
    def +(rhs : self) : self
      Quaternion[@w + rhs.w, @x + rhs.x, @y + rhs.y, @z + rhs.z]
    end

    # Returns the negation of the quaternion.
    def - : self
      Quaternion[-@w, -@x, -@y, -@z]
    end

    # Returns the element-wise addition of the quaternion by *rhs*.
    def -(rhs : self) : self
      Quaternion[@w - rhs.w, @x - rhs.x, @y - rhs.y, @z - rhs.z]
    end

    # Returns the Hamilton product of the quaternion and *rhs*.
    def *(rhs : self) : self
      w = @w * rhs.w - imag.dot(rhs.imag)
      v = @w * rhs.imag + rhs.w * imag + imag.cross(rhs.imag)
      Quaternion[w, v.x, v.y, v.z]
    end

    # Returns the conjugate of *rhs* by the quaternion.
    #
    # The conjugate of *rhs* is calculated as `p* = q * p * q^-1`, where
    # `p` is a quaternion whose vector part is *rhs* and real part
    # equals zero. Thus, the resulting quaternion is computed using the
    # Hamilton product and its vector part corresponds to `p*`. Such
    # operation can be written as `(self * rhs.to_q * inv).imag`, but
    # this method implements an optimized version by using some vector
    # and quaternion identities.
    #
    # If the quaternion encodes a rotation about an axis, this
    # effectively applies such rotation to *rhs*.
    def *(rhs : Vec3) : Vec3
      v = 2 * imag.cross(rhs)
      rhs + @w * v + imag.cross(v)
    end

    # Returns the element-wise multiplication of the quaternion by *rhs*.
    def *(rhs : Number) : self
      Quaternion[@w * rhs, @x * rhs, @y * rhs, @z * rhs]
    end

    # Returns the element-wise division of the quaternion by *rhs*.
    def /(rhs : Number) : self
      Quaternion[@w / rhs, @x / rhs, @y / rhs, @z / rhs]
    end

    # Returns the absolute value (norm) using the Pythagorean theorem.
    def abs : Float64
      Math.sqrt abs2
    end

    # Returns the square of the absolute value (norm).
    def abs2 : Float64
      @w**2 + @x**2 + @y**2 + @z**2
    end

    # Returns the conjugate of the quaternion.
    def conj : self
      Quaternion[@w, -@x, -@y, -@z]
    end

    # Returns the dot product of the quaternion and *rhs*.
    def dot(rhs : self) : Float64
      @w * rhs.w + @x * rhs.x + @y * rhs.y + @z * rhs.z
    end

    # Returns the imaginary part of the quaternion.
    def imag : Vec3
      Vec3[@x, @y, @z]
    end

    def inspect(io : IO) : Nil
      io << "Quaternion[" << @w << ", " << @x << ", " << @y << ", " << @z << ']'
    end

    # Returns the inverse of the quaternion.
    def inv : self
      conj / abs2
    end

    # Returns the normalized quaternion of the quaternion.
    def normalize : self
      return dup if zero?
      self * (1 / abs)
    end

    # Returns the real part of the quaternion.
    def real : Float64
      @w
    end

    def to_s(io : IO) : Nil
      io << "["
      {% for var in %w(w x y z) %}
        io << ' ' if @{{var.id}}.positive?
        io << @{{var.id}}
        {% if var != "z" %}
          io << ' '
        {% end %}
      {% end %}
      io << ']'
    end

    # Returns `true` if the quaternion is a unit quaternion, else
    # `false`.
    def unit? : Bool
      (abs - 1).abs <= 1e-15
    end

    # Returns `true` if the quaternion is a zero quaternion, else
    # `false`.
    def zero? : Bool
      @w == 0 && @x == 0 && @y == 0 && @z == 0
    end
  end

  struct Vec3
    # Returns the conjugate of the quaternion by the inverse of *rhs*.
    # See `Quaternion#*` for details.
    def *(rhs : Quaternion) : self
      rhs.inv * self
    end

    # Returns the quaternion representation of the vector, i.e.,
    # Quaternion[0, x, y, z].
    def to_q : Quaternion
      Quaternion[0, @x, @y, @z]
    end
  end
end
