module Chem::Spatial
  # The quaternion is a mathematical construct that extends the complex
  # numbers and it is useful to encode three-dimensional rotations.
  # Quats are represented by four numbers (w, x, y, z), where w is
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
  # Quats have several useful mathematical properties, e.g.,
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
  # (see `Quat#*` for details).
  #
  # ## Examples
  #
  # ```
  # q = Quat[1, 2, 3, 4]
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
  # p = Quat[4, 3, 2, 1]
  # p + q # => [5.0 5.0 5.0 5.0]
  # p * q # => [-12.0 16.0 4.0 22.0]
  # q * p # => [-12.0 6.0 24.0 12.0]
  # ```
  #
  # Use the convenience methods to encode rotations.
  #
  # ```
  # v = Vec3[1, 2, 3]
  # q = Quat.aligning v, to: Vec3[1, 0, 0]
  # q * v # => [3.742 0.0 0.0]
  # # or
  # v.transform(q)    # => [3.742 0.0 0.0]
  # (q * v).normalize # => [1.0 0.0 0.0]
  #
  # q = Quat.rotation Vec3[0, 1, 0], by: 90
  # q * v # => [3.0 2.0 -1.0]
  # v * q # => [-3.0 2.0 1.0]
  # ```
  #
  # NOTE: Quat multiplication is not commutative: `q * v != v *
  # p`, the former will apply the rotation encoded in *q* to *v* but the
  # latter will produce the inverse rotation. Use `Vec3#transform` to
  # avoid the ambiguity.
  struct Quat
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
      Quat.new w, x, y, z
    end

    # Returns a quaternion encoding the rotation operation to align *u*
    # to *v*.
    def self.aligning(u : Vec3, to v : Vec3) : self
      w = u.cross(v)
      Quat[Math.sqrt(u.abs2 * v.abs2) + u.dot(v), w.x, w.y, w.z].normalize
    end

    # Returns a quaternion encoding the rotation to align *u[0]* to
    # *v[0]* and *u[1]* to *v[1]*.
    #
    # First compute the alignment of *u[0]* to *v[0]*, then the
    # alignment of the transformed *u[1]* to *v[1]* on the plane
    # perpendicular to *v[0]* by taking their projections.
    def self.aligning(u : Tuple(Vec3, Vec3), to v : Tuple(Vec3, Vec3)) : self
      q = Spatial::Quat.aligning(u[0], to: v[0])
      u = (q * u[1]).reject(v[0]) # project onto plane perpendicular to v[0]
      v = v[1].reject(v[0])       # project onto plane perpendicular to v[0]
      qq = Spatial::Quat.aligning u, to: v
      qq * q
    end

    # Returns a quaternion encoding the rotation by the Euler angles.
    #
    # The rotation rotates *x* degrees around the X axis, *y* degrees
    # around the Y axis, and *z* degrees around the y axis; applied in
    # that order (XYZ).
    def self.rotation(x : Number, y : Number, z : Number) : self
      cx = Math.cos(x.radians * 0.5)
      sx = Math.sin(x.radians * 0.5)
      cy = Math.cos(y.radians * 0.5)
      sy = Math.sin(y.radians * 0.5)
      cz = Math.cos(z.radians * 0.5)
      sz = Math.sin(z.radians * 0.5)
      Quat[
        cx * cy * cz - sx * sy * sz,
        sx * cy * cz + cx * sy * sz,
        cx * sy * cz - sx * cy * sz,
        cx * cy * sz + sx * sy * cz,
      ]
    end

    # Returns the identity quaternion (no rotation).
    def self.identity : self
      Quat[1, 0, 0, 0]
    end

    # Returns a quaternion encoding the rotation about the axis vector
    # *rotaxis* by *theta* degrees.
    def self.rotation(about rotaxis : Vec3, by theta : Number) : self
      theta = theta.radians / 2
      vec = Math.sin(theta) * rotaxis.normalize
      Quat[Math.cos(theta), vec.x, vec.y, vec.z]
    end

    # Returns the element-wise addition of the quaternion by *rhs*.
    def +(rhs : self) : self
      Quat[@w + rhs.w, @x + rhs.x, @y + rhs.y, @z + rhs.z]
    end

    # Returns the negation of the quaternion.
    def - : self
      Quat[-@w, -@x, -@y, -@z]
    end

    # Returns the element-wise subtraction of the quaternion by *rhs*.
    def -(rhs : self) : self
      Quat[@w - rhs.w, @x - rhs.x, @y - rhs.y, @z - rhs.z]
    end

    # Returns the Hamilton product of the quaternion and *rhs*.
    def *(rhs : self) : self
      w = @w * rhs.w - imag.dot(rhs.imag)
      v = @w * rhs.imag + rhs.w * imag + imag.cross(rhs.imag)
      Quat[w, v.x, v.y, v.z]
    end

    # Returns the conjugate of *rhs* by the quaternion.
    #
    # The conjugate of *rhs* is calculated as `p* = q * p * q^-1`, where
    # `p` is a quaternion whose vector part is *rhs* and real part
    # equals zero. Thus, the resulting quaternion is computed using the
    # Hamilton product and its vector part corresponds to `p*`. Such
    # operation can be written as `(self * rhs.to_q * inv).imag`, but
    # this method implements an optimized version by using some vector
    # and quaternion identities. The faster method is taken from this
    # [post](https://bit.ly/3G9FENX) of the molecular matters blog.
    #
    # If the quaternion encodes a rotation about an axis, this
    # effectively applies such rotation to *rhs*.
    def *(rhs : Vec3) : Vec3
      v = 2 * imag.cross(rhs)
      rhs + @w * v + imag.cross(v)
    end

    # Returns the element-wise multiplication of the quaternion by *rhs*.
    def *(rhs : Number) : self
      Quat[@w * rhs, @x * rhs, @y * rhs, @z * rhs]
    end

    # Returns the element-wise division of the quaternion by *rhs*.
    def /(rhs : Number) : self
      Quat[@w / rhs, @x / rhs, @y / rhs, @z / rhs]
    end

    # Returns `true` if the elements of the quaternions are close to
    # each other, else `false`. See the `#close_to?` method.
    def =~(other : self) : Bool
      close_to?(other)
    end

    # Returns the absolute value (norm) using the Pythagorean theorem.
    def abs : Float64
      Math.sqrt abs2
    end

    # Returns the square of the absolute value (norm).
    def abs2 : Float64
      @w**2 + @x**2 + @y**2 + @z**2
    end

    # Returns `true` if the elements of the quaternions are within
    # *delta* from each other, else `false`.
    #
    # ```
    # Quat[1, 2, 3, 4].close_to?(Quat[1, 2, 3, 4])                     # => true
    # Quat[1, 2, 3, 4].close_to?(Quat[1.001, 1.999, 3.00004, 4], 1e-3) # => true
    # Quat[1, 2, 3, 4].close_to?(Quat[4, 3, 2, 1])                     # => false
    # Quat[1, 2, 3, 4].close_to?(Quat[1.001, 1.999, 3.00004, 4], 1e-8) # => false
    # ```
    def close_to?(rhs : self, delta : Number = Float64::EPSILON) : Bool
      @w.close_to?(rhs.w, delta) &&
        @x.close_to?(rhs.x, delta) &&
        @y.close_to?(rhs.y, delta) &&
        @z.close_to?(rhs.z, delta)
    end

    # Returns the conjugate of the quaternion.
    def conj : self
      Quat[@w, -@x, -@y, -@z]
    end

    # Returns the dot product of the quaternion and *rhs*.
    def dot(rhs : self) : Float64
      @w * rhs.w + @x * rhs.x + @y * rhs.y + @z * rhs.z
    end

    # Returns the imaginary part of the quaternion.
    def imag : Vec3
      Vec3[@x, @y, @z]
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

    # Returns the rotation matrix equivalent to the quaternion.
    def to_mat3 : Mat3
      return Mat3.zero if zero?

      q = normalize
      w2 = q.w**2
      x2 = q.x**2
      y2 = q.y**2
      z2 = q.z**2

      wx = q.w * q.x
      wy = q.w * q.y
      wz = q.w * q.z
      xy = q.x * q.y
      xz = q.x * q.z
      yz = q.y * q.z

      Mat3[
        [w2 + x2 - y2 - z2, 2 * (xy - wz), 2 * (xz + wy)],
        [2 * (xy + wz), w2 - x2 + y2 - z2, 2 * (yz - wx)],
        [2 * (xz - wy), 2 * (yz + wx), w2 - x2 - y2 + z2],
      ]
    end

    def to_s(io : IO) : Nil
      io << "Quat[ "
      {% for name, i in %w(w x y z) %}
        {% if i > 0 %}
          io << (@{{name.id}} >= 0 ? "  " : ' ')
        {% end %}
        io.printf "%.{{PRINT_PRECISION}}g", @{{name.id}}
      {% end %}
      io << " ]"
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
    # Returns the conjugate of the vector by the inverse of *rhs*. See
    # `Quat#*` for details.
    def *(rhs : Quat) : self
      rhs.inv * self
    end

    # Returns the quaternion representation of the vector, i.e.,
    # `Quat[0, x, y, z]`.
    def to_q : Quat
      Quat[0, @x, @y, @z]
    end
  end
end
