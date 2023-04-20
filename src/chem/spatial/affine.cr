module Chem::Spatial
  # An affine transformation is a geometric transformation in
  # three-dimensional space such as translation, scaling, rotation,
  # reflection, and more. An `AffineTransform` is composed of a linear
  # transformation or map (encoded in a 3x3 matrix) and a translation (a
  # vector).
  #
  # An affine transformation is internally represented by the augmented
  # matrix
  #
  # ```text
  # A = [ M   b  ]
  #     [ 0   1  ]
  # ```
  #
  # where *A* is 4x4 (augmented matrix), *M* is 3x3 (linear map), *b* is
  # 3x1 (translation vector), and the bottom row is [0, 0, 0, 1]. This
  # representation encodes the linear map and translation in a single
  # matrix, which allows to combine and apply transformations by matrix
  # multiplication. Additionally, the affine transformation matrix has
  # some properties that allows for efficient code (see multiplication
  # operator with a vector). For further details, refer to the
  # [Wikipedia
  # article](https://en.wikipedia.org/wiki/Affine_transformation).
  #
  # ### Examples
  #
  # ```
  # scaling = AffineTransform.scaling(2)
  # translation = AffineTransform.translation(Vec3[1, 2, 3])
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
  # transform = AffineTransform.scaling(2).translate(Vec3[1, 2, 3])
  # transform * vec # => Vec3[3.0, 2.0, 5.0]
  # ```
  struct AffineTransform
    # Linear map encoded as a 3x3 matrix.
    getter linear_map : Mat3
    # Translation vector.
    getter offset : Vec3

    # Creates a new transformation with *linear_map* and *offset*.
    def initialize(@linear_map : Mat3, @offset : Vec3)
    end

    # Returns a transformation encoding the rotation operation to align
    # *u* to *v*.
    def self.aligning(u : Vec3, to v : Vec3) : self
      new Quat.aligning(u, v).to_mat3, Vec3.zero
    end

    # Returns a transformation encoding the rotation to align *u[0]* to
    # *v[0]* and *u[1]* to *v[1]*.
    #
    # First compute the alignment of *u[0]* to *v[0]*, then the
    # alignment of the transformed *u[1]* to *v[1]* on the plane
    # perpendicular to *v[0]* by taking their projections.
    def self.aligning(u : Tuple(Vec3, Vec3), to v : Tuple(Vec3, Vec3)) : self
      new Quat.aligning(u, v).to_mat3, Vec3.zero
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
      rotmat, _ = Spatial.qcp pos, ref_pos
      (new(rotmat, Vec3.zero) * translation(-center)).translate(ref_center)
    end

    # Returns the identity transformation.
    def self.identity : self
      AffineTransform.new Mat3.identity, Vec3.zero
    end

    # Returns a transformation that rotates by the Euler angles in
    # degrees. Delegates to `Quat.euler` for computing the rotation.
    def self.euler(x : Number, y : Number, z : Number) : self
      AffineTransform.new Quat.euler(x, y, z).to_mat3, Vec3.zero
    end

    # Returns a transformation that rotates about the axis vector
    # *rotaxis* by *angle* degrees. Delegates to `Quat.rotation` for
    # computing the rotation.
    def self.rotation(about rotaxis : Vec3, by angle : Number) : self
      AffineTransform.new Quat.rotation(rotaxis, angle).to_mat3, Vec3.zero
    end

    # Returns a transformation that scales by *factor*.
    def self.scaling(factor : Number) : self
      AffineTransform.new Mat3.diagonal(factor), Vec3.zero
    end

    # Returns a transformation that scales by the given factors.
    def self.scaling(sx : Number, sy : Number, sz : Number) : self
      AffineTransform.new Mat3.diagonal(sx, sy, sz), Vec3.zero
    end

    # Returns a transformation that translates by *offset*.
    def self.translation(offset : Vec3) : self
      AffineTransform.new Mat3.identity, offset
    end

    # Returns the multiplication of the transformation by *rhs*. It
    # effectively combines two transformation.
    #
    # NOTE: Multiplication of affine transformations is not commutative,
    # i.e., `a * b != b * a`.
    def *(rhs : self) : self
      linear_map = @linear_map * rhs.linear_map
      offset = @offset + @linear_map * rhs.offset
      AffineTransform.new linear_map, offset
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
    # The algorithm exploits the fact that when a matrix looks like this
    #
    # ```text
    # A = [ M   b  ]
    #     [ 0   1  ]
    # ```
    #
    # where *A* is 4x4 (augmented matrix), *M* is 3x3 (linear map), *b*
    # is 3x1 (translation vector), and the bottom row is (0, 0, 0, 1),
    # then
    #
    # ```text
    # inv(A) = [ inv(M)   -inv(M) * b ]
    #          [   0            1     ]
    # ```
    #
    # where `inv(M)` is computed following the standard procedure (see
    # Wikipedia, Inversion of 3x3 matrices).
    #
    # Refer to the [Affine
    # Transformation](https://en.wikipedia.org/wiki/Affine_transformation#Groups)
    # Wikipedia article for a detailed explanation or [this
    # answer](https://stackoverflow.com/a/2625420/1089898) in Stack
    # Overflow.
    def inv : self
      inv_map = @linear_map.inv
      AffineTransform.new inv_map, -inv_map * @offset
    end

    # Returns a quaternion encoding the rotation by the Euler angles.
    # Delegates to `Quat.euler` for computing the rotation.
    def rotate(x : Number, y : Number, z : Number) : self
      rotmat = Quat.euler(x, y, z).to_mat3
      AffineTransform.new rotmat * @linear_map, rotmat * offset
    end

    # Returns the transformation rotated about *rotaxis* by *angle*
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(about rotaxis : Vec3, by angle : Number) : self
      rotmat = Quat.rotation(rotaxis, angle).to_mat3
      AffineTransform.new rotmat * @linear_map, rotmat * offset
    end

    # Returns the rotation component of the transformation.
    def rotation : self
      {{@type}}.new @linear_map, Vec3.zero
    end

    # Returns the transformation scaled by *factor*.
    def scale(by factor : Number) : self
      scale factor, factor, factor
    end

    # Returns the transformation scaled by the given factors.
    def scale(sx : Number, sy : Number, sz : Number) : self
      linear_map = @linear_map * {sx, sy, sz}
      offset = @offset * Vec3[sx, sy, sz]
      AffineTransform.new linear_map, offset
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
      AffineTransform.new linear_map, @offset + offset
    end

    # Returns the translation component of the transformation.
    def translation : self
      {{@type}}.new Mat3.identity, @offset
    end
  end

  struct Vec3
    # Returns the multiplication of the vector by *rhs*. It effectively
    # applies the inverse transformation to the vector.
    def *(rhs : AffineTransform) : self
      rhs.inv * self
    end
  end
end

struct Chem::Spatial::AffineTransform
  def self.aligning(pos : AtomCollection, to ref_pos : AtomCollection) : self
    aligning pos.coords, ref_pos.coords
  end
end
