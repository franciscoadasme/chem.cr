module Chem::Spatial
  # A `Transform` encodes an affine transformation in 3D space such as
  # translation, scaling, rotation, reflection, and more.
  #
  # An affine transformation is the composition of a linear map *A* (3x3
  # matrix) and a translation *b* (3x1 vector), which can be represented
  # by the augmented 4x4 matrix:
  #
  # ```text
  # [ A   b ]
  # [ 0   1 ]
  # ```
  #
  # where the bottom row is [0, 0, 0, 1]. This representation encodes
  # the linear map and translation in a single matrix, which allows to
  # combine and apply transformations by matrix multiplication.
  # Additionally, the affine transformation matrix has some properties
  # that allows for efficient code (see the multiplication operator with
  # a vector). For further details, refer to the [Wikipedia
  # article](https://en.wikipedia.org/wiki/Affine_transformation).
  #
  # The transformation is internally represented by a `Mat3`
  # (`#linear_map`) and `Vec3` (`#offset`) instances.
  #
  # ### Examples
  #
  # ```
  # scaling = Transform.scaling(2)
  # translation = Transform.translation(Vec3[1, 2, 3])
  # vec = Vec3[1, 0, 1]
  #
  # # apply the transformation
  # scaling * vec     # => Vec3[2.0, 0.0, 2.0]
  # translation * vec # => Vec3[2.0, 2.0, 4.0]
  # # or
  # vec.transform(scaling)     # => Vec3[2.0, 0.0, 2.0]
  # vec.transform(translation) # => Vec3[2.0, 2.0, 4.0]
  #
  # # note that multiplication is not commutative
  # scaling * vec # => Vec3[2.0, 0.0, 2.0]
  # vec * scaling # => Vec3[0.5, 0.0, 0.5] # inverse transformation
  #
  # # combine transformations
  # translate_scale = scaling * translation # translates then scales
  # translate_scale * vec                   # => Vec3[4.0, 4.0, 8.0]
  # scale_translate = translation * scaling # scales than translates
  # scale_translate * vec                   # => Vec3[3.0, 2.0, 5.0]
  #
  # # chain methods for composing a transformation
  # transform = Transform.scaling(2).translate(Vec3[1, 2, 3])
  # transform * vec # => Vec3[3.0, 2.0, 5.0]
  # ```
  struct Transform
    # Linear map encoded as a 3x3 matrix.
    getter linear_map : Mat3
    # Translation vector.
    getter offset : Vec3

    # Creates a new transformation with *linear_map* and *offset*.
    def initialize(@linear_map : Mat3, @offset : Vec3 = Vec3.zero)
    end

    # Returns a transformation encoding the rotation operation to align
    # *u* to *v*.
    def self.aligning(u : Vec3, to v : Vec3) : self
      rotation Quat.aligning(u, v)
    end

    # Returns a transformation encoding the rotation to align *u[0]* to
    # *v[0]* and *u[1]* to *v[1]*.
    #
    # First compute the alignment of *u[0]* to *v[0]*, then the
    # alignment of the transformed *u[1]* to *v[1]* on the plane
    # perpendicular to *v[0]* by taking their projections.
    def self.aligning(u : Tuple(Vec3, Vec3), to v : Tuple(Vec3, Vec3)) : self
      rotation Quat.aligning(u, v)
    end

    # Returns the transformation encoding the rotation and traslation to
    # align *pos* onto *ref_pos*. Raises `ArgumentError` if the two
    # coordinate sets are of different size.
    #
    # The optimal rotation matrix is computed by minimizing the root
    # mean square deviation (RMSD) using the QCP method (refer to
    # `Spatial.qcp` for details).
    def self.aligning(pos : CoordinatesProxy, to ref_pos : CoordinatesProxy) : self
      pos = pos.to_a         # FIXME: avoid copying coordinates
      ref_pos = ref_pos.to_a # FIXME: avoid copying coordinates
      raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size

      center = pos.mean
      pos.map! &.-(center)
      ref_center = ref_pos.mean
      ref_pos.map! &.-(ref_center)
      quat, _ = Spatial.qcp pos, ref_pos
      translation(-center).rotate(quat).translate(ref_center)
    end

    # Returns the identity transformation.
    def self.identity : self
      new Mat3.identity
    end

    # Returns a transformation that rotates by the Euler angles in
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def self.rotation(x : Number, y : Number, z : Number) : self
      rotation Quat.rotation(x, y, z)
    end

    # Returns a transformation that rotates about the axis vector
    # *rotaxis* by *angle* degrees. Delegates to `Quat.rotation` for
    # computing the rotation.
    def self.rotation(about rotaxis : Vec3, by angle : Number) : self
      rotation Quat.rotation(rotaxis, angle)
    end

    # Returns a transformation that applies the rotation encoded by
    # the given quaternion.
    def self.rotation(quat : Quat) : self
      new quat.to_mat3
    end

    # Returns a transformation that scales by *factor*.
    def self.scaling(factor : Number) : self
      new Mat3.diagonal(factor)
    end

    # Returns a transformation that scales by the given factors.
    def self.scaling(sx : Number, sy : Number, sz : Number) : self
      new Mat3.diagonal(sx, sy, sz)
    end

    # Returns a transformation that translates by *offset*.
    def self.translation(offset : Vec3) : self
      new Mat3.identity, offset
    end

    # Returns the multiplication of the transformation by *rhs*. It
    # effectively combines two transformation.
    #
    # NOTE: Multiplication of transformations is not commutative, i.e.,
    # `a * b != b * a`.
    #
    # ```
    # scaling = Transform.scaling(2)
    # translation = Transform.translation(Vec3[1, 2, 3])
    # vec = Vec3[1, 0, 1]
    #
    # translate_scale = scaling * translation # translates then scales
    # translate_scale * vec                   # => Vec3[4.0, 4.0, 8.0]
    # scale_translate = translation * scaling # scales than translates
    # scale_translate * vec                   # => Vec3[3.0, 2.0, 5.0]
    def *(rhs : self) : self
      linear_map = @linear_map * rhs.linear_map
      offset = @offset + @linear_map * rhs.offset
      Transform.new linear_map, offset
    end

    # Returns the multiplication of the transformation by *rhs*. It
    # effectively applies the transformation to *rhs*.
    def *(rhs : Vec3) : Vec3
      @linear_map * rhs + @offset
    end

    def ==(rhs : self) : Bool
      @linear_map == rhs.linear_map && @offset == rhs.offset
    end

    # Returns `true` if the elements of the quaternions are within
    # *delta* from each other, else `false`.
    def close_to?(rhs : self, delta : Float64 = Float64::EPSILON) : Bool
      @linear_map.close_to?(rhs.linear_map, delta) &&
        @offset.close_to?(rhs.offset, delta)
    end

    # Returns the inverse transformation.
    #
    # The algorithm exploits the fact that the affine transformation
    # matrix is defined as
    #
    # ```text
    # [ A   b ]
    # [ 0   1 ]
    # ```
    #
    # where *A* is the linear map (3x3 matrix), *b* is the translation
    # vector (3x1 vector), and the bottom row is [0, 0, 0, 1]. In such
    # case, the inverse matrix can be computed as
    #
    # ```text
    # [ inv(A)   -inv(A) * b ]
    # [   0            1     ]
    # ```
    #
    # where `inv(A)` is computed following the standard procedure (see
    # [Inversion of 3x3 matrices](https://en.wikipedia.org/wiki/Invertible_matrix#Inversion_of_3_%C3%97_3_matrices) at Wikipedia).
    #
    # Refer to the [Affine
    # Transformation](https://en.wikipedia.org/wiki/Affine_transformation#Groups)
    # Wikipedia article for a detailed explanation or [this
    # answer](https://stackoverflow.com/a/2625420/1089898) in Stack
    # Overflow.
    def inv : self
      inv_map = @linear_map.inv
      Transform.new inv_map, -inv_map * @offset
    end

    # Returns the transformation encoding the rotation by the Euler
    # angles. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(x : Number, y : Number, z : Number) : self
      rotate Quat.rotation(x, y, z)
    end

    # Returns the transformation rotated about *rotaxis* by *angle*
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(about rotaxis : Vec3, by angle : Number) : self
      rotate Quat.rotation(rotaxis, angle)
    end

    # Returns the transformation rotated by the given quaternion.
    def rotate(quat : Quat) : self
      rotmat = quat.to_mat3
      self.class.new rotmat * @linear_map, rotmat * offset
    end

    # Returns the rotation component of the transformation.
    def rotation : self
      {{@type}}.new @linear_map
    end

    # Returns the transformation scaled by *factor*.
    def scale(by factor : Number) : self
      scale factor, factor, factor
    end

    # Returns the transformation scaled by the given factors.
    def scale(sx : Number, sy : Number, sz : Number) : self
      linear_map = @linear_map * {sx, sy, sz}
      offset = @offset * Vec3[sx, sy, sz]
      Transform.new linear_map, offset
    end

    def to_s(io : IO) : Nil
      format_spec = "%.#{PRINT_PRECISION}g"
      io << "["
      0.upto(2) do |i|
        io << "[ "
        0.upto(2) do |j|
          io << (@linear_map[i, j] >= 0 ? "  " : ' ') if j > 0
          io.printf format_spec, @linear_map[i, j]
        end
        io << (@offset[i] >= 0 ? "  " : ' ')
        io.printf format_spec, @offset[i]
        io << " ]"
        io << ", " if i < 2
      end
      io << ", [0  0  0  1]]"
    end

    # Returns the transformation translated by *offset*.
    def translate(by offset : Vec3) : self
      Transform.new linear_map, @offset + offset
    end

    # Returns the translation component of the transformation.
    def translation : self
      {{@type}}.new Mat3.identity, @offset
    end
  end
end

struct Chem::Spatial::Transform
  def self.aligning(pos : AtomCollection, to ref_pos : AtomCollection) : self
    aligning pos.coords, ref_pos.coords
  end
end
