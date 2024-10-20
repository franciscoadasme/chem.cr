module Chem::Spatial
  # A parallelepiped is a three-dimensional figure formed by six
  # parallelograms. It is defined by three vectors (basis) and it's
  # useful for representing spatial bounds and unit cells.
  #
  # It is internally represented by a 3x3 matrix, where each column
  # correspond to a basis vector (see `Mat3.basis`), where
  # coordinates are expressed in Cartesian space (angstroms). In this
  # way, the basis matrix can be used to transform from Cartesian to
  # fractional coordinates, and viceversa, by matrix multiplication (see
  # `#cart` and `#fract`).
  struct Parallelepiped
    # Matrix containing the basis vectors.
    getter basis : Mat3
    # Origin of the parallelepiped.
    getter origin : Vec3

    # Caches the inverse matrix for coordinate conversion.
    @inv_basis : Mat3?

    # Creates a `Parallelepiped` with *basis* located at *origin*.
    def initialize(@basis : Mat3, @origin : Vec3 = Vec3.zero)
    end

    # Reads a parallelepiped from *io* in the given *format*. See also:
    # `IO#read_bytes`.
    def self.from_io(io : IO, format : IO::ByteFormat) : self
      new io.read_bytes(Mat3, format), io.read_bytes(Vec3, format)
    end

    # Creates a `Parallelepiped` with the given basis vectors located at
    # *origin*.
    def self.new(i : Vec3, j : Vec3, k : Vec3, origin : Vec3 = Vec3.zero) : self
      new Mat3.basis(i, j, k), origin
    end

    # Creates a `Parallelepiped` with the given lengths (in angstroms)
    # and angles (in degrees) located at *origin*. Raises
    # `ArgumentError` if any of the lengths or angles is negative.
    #
    # NOTE: The first basis vector will be aligned to the X axis and the
    # second basis vector will lie in the XY plane.
    def self.new(size : NumberTriple | Size3,
                 angles : NumberTriple = {90, 90, 90},
                 origin : Vec3 = Vec3.zero) : self
      size = Size3[*size] unless size.is_a?(Size3)
      raise ArgumentError.new("Negative angle") if angles.any?(&.negative?)
      if angles.all?(&.close_to?(90))
        new Mat3.diagonal(size[0], size[1], size[2]), origin
      else
        cos_alpha = Math.cos angles[0].radians
        cos_beta = Math.cos angles[1].radians
        cos_gamma = Math.cos angles[2].radians
        sin_gamma = Math.sin angles[2].radians

        kx = size[2] * cos_beta
        ky = size[2] * (cos_alpha - cos_beta * cos_gamma) / sin_gamma
        kz = Math.sqrt size[2]**2 - kx**2 - ky**2

        bi = Vec3[size[0], 0, 0]
        bj = Vec3[size[1] * cos_gamma, size[1] * sin_gamma, 0]
        bk = Vec3[kx, ky, kz]

        new bi, bj, bk, origin
      end
    end

    # Creates a `Parallelepiped` spanning from *vmin* to *vmax*.
    def self.new(vmin : Vec3, vmax : Vec3) : self
      new Size3[vmax.x - vmin.x, vmax.y - vmin.y, vmax.z - vmin.z], origin: vmin
    end

    # Creates a `Parallelepiped` with the given lengths placed at the
    # origin.
    def self.[](a : Number, b : Number, c : Number) : self
      new Size3[a, b, c]
    end

    # Creates a cubic parallelepiped (*a* = *b* = *c* and *α* = *β* =
    # *γ* = 90°).
    def self.cubic(a : Number) : self
      new Size3[a, a, a]
    end

    # Creates a hexagonal parallelepiped (*a* = *b*, *α* = *β* = 90°,
    # and *γ* = 120°).
    def self.hexagonal(a : Number, c : Number) : self
      new Size3[a, a, c], {90, 90, 120}
    end

    # Creates a monoclinic parallelepiped (*a* ≠ *c*, *α* = *γ* = 90°,
    # and *β* ≠ 90°).
    def self.monoclinic(a : Number, c : Number, beta : Number) : self
      new({a, a, c}, {90, beta, 90})
    end

    # Creates an orthorhombic parallelepiped (*a* ≠ *b* ≠ *c* and *α* =
    # *β* = *γ* = 90°).
    def self.orthorhombic(a : Number, b : Number, c : Number) : self
      new({a, b, c}, {90, 90, 90})
    end

    # Creates an rhombohedral parallelepiped (*a* = *b* = *c* and *α* =
    # *β* = *γ* ≠ 90°).
    def self.rhombohedral(a : Number, alpha : Number) : self
      new({a, a, a}, {alpha, alpha, alpha})
    end

    # Creates an tetragonal parallelepiped (*a* = *b* ≠ *c* and *α* =
    # *β* = *γ* = 90°).
    def self.tetragonal(a : Number, c : Number) : self
      new({a, a, c}, {90, 90, 90})
    end

    # Returns a parallelepiped with the basis vectors multiplied by
    # *value*.
    def *(value : Number) : self
      new i * value, j * value, k * value
    end

    def ==(rhs : self) : Bool
      @origin == rhs.origin && @basis == rhs.basis
    end

    # Returns `true` if the elements of the parallelepipeds are close to
    # each other, else `false`. See the `#close_to?` method.
    def =~(other : self) : Bool
      close_to?(other)
    end

    # Returns the parallelepiped angles (alpha, beta, gamma) in degrees.
    def angles : NumberTriple
      bi, bj, bk = basisvec
      {bj.angle(bk), bi.angle(bk), bi.angle(bj)}.map(&.degrees)
    end

    # Returns the basis vectors.
    def basisvec : Tuple(Vec3, Vec3, Vec3)
      {Vec3[*@basis[.., 0]], Vec3[*@basis[.., 1]], Vec3[*@basis[.., 2]]}
    end

    # Returns the vector in Cartesian coordinates equivalent to the
    # given fractional coordinates.
    def cart(vec : Vec3) : Vec3
      @basis * vec
    end

    # Returns the center of the parallelepiped.
    def center : Vec3
      @origin + basisvec.sum * 0.5
    end

    # Centers the parallelepiped at *vec*.
    def center_at(vec : Vec3) : self
      translate vec - center
    end

    # Centers the parallelepiped at the origin.
    def center_at_origin : self
      translate -center
    end

    # Returns `true` if the values of the parallelepipeds are within
    # *delta* from each other, else `false`.
    def close_to?(rhs : self, delta : Number = Float64::EPSILON) : Bool
      @origin.close_to?(rhs.origin, delta) &&
        @basis.close_to?(rhs.basis, delta)
    end

    # Returns `true` if the parallelepiped is cubic (*a* = *b* = *c* and
    # *α* = *β* = *γ* = 90°), else `false`.
    def cubic? : Bool
      a, b, c = size
      a.close_to?(b, 1e-15) && b.close_to?(c, 1e-15) && orthogonal?
    end

    # Yields each parallelepiped' edge as a pair of vertices.
    def each_edge(& : Vec3, Vec3 ->) : Nil
      bi, bj, bk = basisvec
      yield @origin, @origin + bi
      yield @origin, @origin + bj
      yield @origin, @origin + bk
      yield @origin + bi, @origin + bi + bj
      yield @origin + bi, @origin + bi + bk
      yield @origin + bj, @origin + bi + bj
      yield @origin + bj, @origin + bj + bk
      yield @origin + bi + bj, @origin + bi + bj + bk
      yield @origin + bk, @origin + bi + bk
      yield @origin + bk, @origin + bj + bk
      yield @origin + bi + bk, @origin + bi + bj + bk
      yield @origin + bj + bk, @origin + bi + bj + bk
    end

    # Yields parallelepiped' vertices.
    #
    # ```
    # Parallelepiped[5, 10, 20].each_vertex { |vec| puts vec }
    # ```
    #
    # Prints:
    #
    # ```text
    # Vec3[0.0, 0.0, 0.0]
    # Vec3[0.0, 0.0, 20.0]
    # Vec3[0.0, 10.0, 0.0]
    # Vec3[0.0, 10.0, 20.0]
    # Vec3[5.0, 0.0, 0.0]
    # Vec3[5.0, 0.0, 20.0]
    # Vec3[5.0, 10.0, 0.0]
    # Vec3[5.0, 10.0, 20.0]
    # ```
    def each_vertex(& : Vec3 ->) : Nil
      bi, bj, bk = basisvec
      2.times do |di|
        2.times do |dj|
          2.times do |dk|
            yield @origin + bi * di + bj * dj + bk * dk
          end
        end
      end
    end

    # Returns the parallelepiped' edges as pairs of vertices.
    def edges : Array(Tuple(Vec3, Vec3))
      edges = Array(Tuple(Vec3, Vec3)).new(12)
      each_edge { |u, v| edges << {u, v} }
      edges
    end

    # Returns the vector in fractional coordinates equivalent to the
    # given Cartesian coordinates.
    def fract(vec : Vec3) : Vec3
      inv_basis * vec
    end

    # Returns `true` if the parallelepiped is hexagonal (*a* = *b*, *α*
    # = *β* = 90°, and *γ* = 120°), else `false`.
    def hexagonal? : Bool
      a, b, _ = size
      alpha, beta, gamma = angles
      a.close_to?(b, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        beta.close_to?(90, 1e-8) &&
        gamma.close_to?(120, 1e-8)
    end

    # Returns the vector's image with respect to the parallelepiped.
    #
    # ```
    # pld = new Parallelepiped.new({2, 2, 3}, {90, 90, 120})
    # pld.i # => Vec3[2.0, 0.0, 0.0]
    # pld.j # => Vec3[-1, 1.732, 0.0]
    # pld.k # => Vec3[0.0, 0.0, 3.0]
    #
    # vec = Vec3[1, 1, 1.5]
    # pld.image(vec, {1, 0, 0}) # => Vec3[3.0, 1.0, 1.5]
    # pld.image(vec, {0, 1, 0}) # => Vec3[0.0, 2.732, 1.5]
    # pld.image(vec, {0, 0, 1}) # => Vec3[1.0, 1.0, 4.5]
    # pld.image(vec, {1, 0, 1}) # => Vec3[3.0, 1.0, 4.5]
    # pld.image(vec, {1, 1, 1}) # => Vec3[2.0, 2.732, 4.5]
    # ```
    def image(vec : Vec3, ix : Tuple(Int, Int, Int)) : Vec3
      {% begin %}
        {% for i in 0..2 %}
          basisvec[{{i}}] * ix[{{i}}] +
        {% end %}
        vec
      {% end %}
    end

    # Returns `true` if the parallelepiped encloses *other*, `false`
    # otherwise.
    #
    # It effectively checks if every vertex of *other* is contained by
    # the parallelepiped.
    #
    # ```
    # pld = Parallelepiped.new({10, 10, 10}, {90, 90, 120})
    # pld.includes? Parallelepiped[5, 4, 6]                        # => true
    # pld.includes? Parallelepiped.new(Vec3[-1, 2, -4], {5, 4, 6}) # => false
    # ```
    def includes?(other : self) : Bool
      other.each_vertex do |vec|
        return false unless vec.in?(self)
      end
      true
    end

    # Returns `true` if the parallelepiped encloses *vec*, `false`
    # otherwise.
    #
    # ```
    # pld = Parallelepiped.new({23.803, 23.828, 5.387}, {90, 90, 120})
    # pld.includes? Vec3[10, 20, 2]  # => true
    # pld.includes? Vec3[0, 0, 0]    # => true
    # pld.includes? Vec3[30, 30, 10] # => false
    # pld.includes? Vec3[-3, 10, 2]  # => true
    # pld.includes? Vec3[-3, 2, 2]   # => false
    # ```
    def includes?(vec : Vec3) : Bool
      vec -= @origin unless @origin.zero?
      bi, bj, bk = basisvec
      # TODO: replace by an internal enum (xyz and triclinic) that is
      # updated on new basis to avoid doing this each time
      if xyz?
        0 <= vec.x <= bi.x && 0 <= vec.y <= bj.y && 0 <= vec.z <= bk.z
      else
        vec = fract(vec).map &.round(Float64::DIGITS)
        0 <= vec.x <= 1 && 0 <= vec.y <= 1 && 0 <= vec.z <= 1
      end
    end

    def inspect(io : IO) : Nil
      format_spec = "%.#{PRINT_PRECISION}g"
      io << self.class.name << "(@origin=[ "
      io.printf format_spec, @origin.x
      io << ' '
      io.printf format_spec, @origin.y
      io << ' '
      io.printf format_spec, @origin.z
      io << " ], @basis=" << @basis << ')'
    end

    # Inverted matrix basis.
    private def inv_basis : Mat3
      @inv_basis ||= @basis.inv
    end

    # Returns `true` if the parallelepiped is monoclinic (*a* ≠ *c*, *α*
    # = *γ* = 90°, and *β* ≠ 90°), else `false`.
    def monoclinic? : Bool
      a, _, c = size
      alpha, beta, gamma = angles
      !a.close_to?(c, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        !beta.close_to?(90, 1e-8) &&
        gamma.close_to?(90, 1e-8)
    end

    # Returns `true` if the parallelepiped is orthogonal (*α* = *β* =
    # *γ* = 90°), else `false`.
    def orthogonal? : Bool
      angles.all? &.close_to?(90, 1e-8)
    end

    # Returns `true` if the parallelepiped is orthorhombic (*a* ≠ *b* ≠
    # *c* and *α* = *β* = *γ* = 90°), else `false`.
    def orthorhombic? : Bool
      a, b, c = size
      !a.close_to?(b, 1e-15) &&
        !a.close_to?(c, 1e-15) &&
        !b.close_to?(c, 1e-15) &&
        orthogonal?
    end

    # Returns a new parallelepiped by expanding the extents by *padding*
    # in each direction. *padding* can be either a single value, three
    # values, or a `Size3` instance.
    #
    # If *centered* is `true`, the origin will be changed such that the
    # center does not change, else it will be kept intact.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[1, 5, 3], {10, 5, 12})
    #
    # other = pld.pad(2.5)
    # other.size                 # => Size3[15, 10, 17]
    # other.origin == pld.origin # => false
    # other.center == pld.center # => true
    #
    # other = pld.pad(2.5, centered: false)
    # other.size                 # => Size3[15, 10, 17]
    # other.origin == pld.origin # => true
    # other.center == pld.center # => false
    # ```
    #
    # NOTE: Note that its size is actually increased by `padding * 2`.
    def pad(padding : Number, centered : Bool = true) : self
      pad padding, padding, padding, centered
    end

    # :ditto:
    def pad(padding : Size3, centered : Bool = true) : self
      new_origin = @origin
      if centered
        new_origin -= basisvec.map_with_index { |bv, i| bv.resize(padding[i]) }.sum
      end
      padding *= 2
      new_basis = Mat3.basis *basisvec.map_with_index { |bv, i| bv.pad(padding[i]) }
      self.class.new new_basis, new_origin
    end

    # :ditto:
    def pad(px : Number, py : Number, pz : Number, centered : Bool = true) : self
      pad Size3[px, py, pz], centered
    end

    # Returns a parallelepiped by resizing the basis vectors to the
    # given size.
    #
    # ```
    # pld = Parallelepiped.hexagonal(1, 2)
    # pld.angles # => {90, 90, 120}
    # pld.size   # => Size3[1, 1, 2]
    #
    # other = pld.resize(Size3[5, 5, 12])
    # other.angles # => {90, 90, 120}
    # other.size   # => Size3[5, 5, 12]
    # ```
    def resize(size : Chem::Spatial::Size3) : self
      transform do |bi, bj, bk|
        {bi.resize(size[0]), bj.resize(size[1]), bk.resize(size[2])}
      end
    end

    # Returns a parallelepiped by resizing the basis vectors to the
    # given values.
    #
    # ```
    # pld = Parallelepiped.hexagonal(1, 2)
    # pld.angles # => {90, 90, 120}
    # pld.size   # => Size3[1, 1, 2]
    #
    # other = pld.resize(5, 5, 12)
    # other.angles # => {90, 90, 120}
    # other.size   # => Size3[5, 5, 12]
    # ```
    #
    # Use `nil` to keep the current size:
    #
    # ```
    # other = pld.resize(nil, 5, nil)
    # other.angles # => {90, 90, 120}
    # other.size   # => Size3[1, 5, 12]
    # ```
    def resize(si : Number?, sj : Number?, sk : Number?) : self
      vi, vj, vk = basisvec
      vi = vi.resize(si) if si
      vj = vj.resize(sj) if sj
      vk = vk.resize(sk) if sk
      self.class.new vi, vj, vk
    end

    # Yields the basis vectors' sizes to the given block, and returns a
    # parallelepiped by resizing them to the returned values.
    #
    # ```
    # pld = Parallelepiped.hexagonal(1, 2)
    # pld.angles # => {90, 90, 120}
    # pld.size   # => Size3[1, 1, 2]
    #
    # other = pld.resize { |a, b, c| {a * 2, b / 10, c} }
    # other.angles # => {90, 90, 120}
    # other.size   # => Size3[2, 0.1, 2]
    # ```
    def resize(& : Float64, Float64, Float64 -> {Float64, Float64, Float64}) : self
      vi, vj, vk = basisvec
      a, b, c = yield vi.abs, vj.abs, vk.abs
      self.class.new vi.resize(a), vj.resize(b), vk.resize(c)
    end

    # Returns a parallelepiped by padding the basis vectors by the given
    # values.
    #
    # ```
    # pld = Parallelepiped.hexagonal(1, 2)
    # pld.angles # => {90, 90, 120}
    # pld.size   # => Size3[1, 1, 2]
    #
    # other = pld.resize_by(2, 3, -0.5)
    # other.angles # => {90, 90, 120}
    # other.size   # => Size3[3, 4, 1.5]
    # ```
    def resize_by(a : Number, b : Number, c : Number) : self
      vi, vj, vk = basisvec
      self.class.new vi.pad(a), vj.pad(b), vk.pad(c)
    end

    # Returns `true` if the parallelepiped is rhombohedral (*a* = *b* =
    # *c* and *α* = *β* = *γ* ≠ 90°), else `false`.
    def rhombohedral? : Bool
      a, b, c = size
      alpha, beta, gamma = angles
      a.close_to?(b, 1e-15) &&
        a.close_to?(c, 1e-15) &&
        alpha.close_to?(beta, 1e-8) &&
        alpha.close_to?(gamma, 1e-8) &&
        !alpha.close_to?(90, 1e-8)
    end

    # Returns the parallelepiped rotated by the given Euler angles in
    # degrees. Delegates to `Quat.rotation` for computing the rotation.
    def rotate(x : Number, y : Number, z : Number) : self
      rotate Quat.rotation(x, y, z)
    end

    # Returns the parallelepiped rotated about the axis vector *rotaxis*
    # by *angle* degrees. Delegates to `Quat.rotation` for computing the
    # rotation.
    def rotate(about rotaxis : Vec3, by angle : Number) : self
      rotate Quat.rotation(rotaxis, angle)
    end

    # Returns the parallelepiped rotated by the given quaternion.
    def rotate(quat : Quat) : self
      transform Transform.rotation(quat)
    end

    # Returns the parallelepiped with the basis vectors scaled by the
    # given amount.
    #
    # ```
    # pld = Chem::Spatial::Parallelepiped.hexagonal(1, 3)
    # pld.scale(10).size              # => Size3[10, 10, 30]
    # pld.scale(10).angles            # => {90, 90, 120}
    # pld.scale(10, 100, 1000).size   # => Size3[10, 100, 3000]
    # pld.scale(10, 100, 1000).angles # => {90, 90, 120}
    # ```
    def scale(factor : Number) : self
      scale factor, factor, factor
    end

    # :ditto:
    def scale(si : Number, sj : Number, sk : Number) : self
      vi, vj, vk = basisvec
      self.class.new vi * si, vj * sj, vk * sk
    end

    # Returns the lengths of the basis vectors.
    def size : Size3
      Size3[*basisvec.map(&.abs)]
    end

    # Returns `true` if the parallelepiped is tetragonal (*a* = *b* ≠
    # *c* and *α* = *β* = *γ* = 90°), else `false`.
    def tetragonal? : Bool
      a, b, c = size
      a.close_to?(b, 1e-15) && !a.close_to?(c, 1e-15) && orthogonal?
    end

    # Writes the binary representation of the parallelepiped to *io* in
    # the given *format*. See also `IO#write_bytes`.
    def to_io(io : IO, format : IO::ByteFormat = :system_endian) : Nil
      io.write_bytes @basis, format
      io.write_bytes @origin, format
    end

    # Returns the parallelepiped resulting of applying the given
    # transformation.
    #
    # NOTE: the rotation will be applied about the center of the
    # parallelepiped. Translation will be applied afterwards.
    def transform(transformation : Transform) : self
      new_basisvec = basisvec.map &.transform(transformation.rotation)
      center_offset = (new_basisvec.sum - basisvec.sum) * 0.5
      origin = @origin + transformation.offset - center_offset
      {{@type}}.new Mat3.basis(*new_basisvec), origin
    end

    # Returns a new parallelepiped translated by *offset*.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[-5, 1, 20], {10, 10, 10}, {90, 90, 120})
    # pld.translate Vec3[1, 2, 10]
    # pld.origin # => Vec3[-4.0, 3.0, 30.0]
    # ```
    def translate(offset : Vec3) : self
      {{@type}}.new @basis, @origin + offset
    end

    # Returns a new parallelepiped with the return value of the given
    # block, which is invoked with the basis vectors.
    #
    # ```
    # pld = Parallelepiped.cubic(10).transform do |bi, bj, bk|
    #   bi *= 2
    #   bk /= 0.4
    #   {bi, bj, bk}
    # end
    # pld.basisvec[0] # => Vec3[20, 0, 0]
    # pld.basisvec[1] # => Vec3[0, 10, 0]
    # pld.basisvec[2] # => Vec3[0, 0, 25]
    # ```
    def transform(& : Vec3, Vec3, Vec3 -> {Vec3, Vec3, Vec3}) : self
      bi, bj, bk = basisvec
      components = yield bi, bj, bk
      self.class.new *components
    end

    # Returns `true` if the parallelepiped is triclinic (not orthogonal,
    # hexagonal, monoclinic, nor rhombohedral), else `false`.
    def triclinic? : Bool
      !orthogonal? && !hexagonal? && !monoclinic? && !rhombohedral?
    end

    # Returns parallelepiped' vertices.
    #
    # ```
    # pld = Parallelepiped[5, 10, 20]
    # pld.vertices # => [Vec3[0.0, 0.0, 0.0], Vec3[0.0, 0.0, 20.0], ...]
    # ```
    def vertices : Array(Vec3)
      vertices = [] of Vec3
      each_vertex { |vec| vertices << vec }
      vertices
    end

    # Returns the maximum vertex.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[1.5, 3, -0.4], {10, 10, 12}, {90, 90, 120})
    # pld.vmax # => Vec3[6.5, 11.66, 11.6]
    # ```
    def vmax : Vec3
      @origin + basisvec.sum
    end

    # Returns the minimum vertex. This is equivalent to the
    # parallelepiped's origin.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[1.5, 3, -0.4], {10, 10, 12}, {90, 90, 120})
    # pld.vmin # => Vec3[1.5, 3, -0.4]
    # ```
    def vmin : Vec3
      @origin
    end

    # Returns the volume of the parallelepiped.
    def volume : Float64
      @basis.det
    end

    # Returns the vector by wrapping it into the parallelepiped. The
    # vector is assumed to be expressed in Cartesian coordinates.
    def wrap(vec : Vec3) : Vec3
      cart(fract(vec - @origin).wrap) + @origin
    end

    # Returns the vector by wrapping it into the parallelepiped centered
    # at *center*. The vector is assumed to be expressed in Cartesian
    # coordinates.
    def wrap(vec : Vec3, around center : Vec3) : Vec3
      cart(fract(vec - @origin).wrap(fract(center))) + @origin
    end

    # Whether the parallelepiped is aligned to the X, Y, and Z axes.
    def xyz? : Bool
      orthogonal? && basisvec[0].parallel?(:x)
    end
  end
end
