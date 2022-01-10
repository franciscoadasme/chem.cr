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
  class Parallelepiped
    # Matrix containing the basis vectors.
    getter basis : Mat3
    # Origin of the parallelepiped.
    getter origin : Vec3

    # Caches the inverse matrix for coordinate conversion.
    @inv_basis : Mat3?

    # Creates a `Parallelepiped` with *basis* located at *origin*.
    def initialize(@origin : Vec3, @basis : Mat3)
    end

    # Creates a `Parallelepiped` with *basis* located at the origin.
    def self.new(basis : Mat3) : self
      new Vec3.zero, basis
    end

    # Creates a `Parallelepiped` with the given basis vectors located at
    # the origin.
    def self.new(i : Vec3, j : Vec3, k : Vec3) : self
      new Vec3.zero, i, j, k
    end

    # Creates a `Parallelepiped` with the given basis vectors located at
    # *origin*.
    def self.new(origin : Vec3, i : Vec3, j : Vec3, k : Vec3) : self
      new origin, Mat3.basis(i, j, k)
    end

    # Creates a `Parallelepiped` with the given lengths (in angstroms)
    # and angles (in degrees) located at the origin. Raises
    # `ArgumentError` if any of the lengths or angles is negative.
    #
    # NOTE: The first basis vector will be aligned to the X axis and the
    # second basis vector will lie in the XY plane.
    def self.new(size : NumberTriple | Size3,
                 angles : NumberTriple = {90, 90, 90}) : self
      new Vec3.zero, size, angles
    end

    # Creates a `Parallelepiped` with the given lengths (in angstroms)
    # and angles (in degrees) located at *origin*. Raises
    # `ArgumentError` if any of the lengths or angles is negative.
    #
    # NOTE: The first basis vector will be aligned to the X axis and the
    # second basis vector will lie in the XY plane.
    def self.new(origin : Vec3,
                 size : NumberTriple | Size3,
                 angles : NumberTriple = {90, 90, 90}) : self
      raise ArgumentError.new("Negative size") if !size.is_a?(Size3) && size.any?(&.negative?)
      raise ArgumentError.new("Negative angle") if angles.any?(&.negative?)
      if angles.all?(&.close_to?(90))
        new origin, Mat3.diagonal(size[0], size[1], size[2])
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

        new origin, Mat3.basis(bi, bj, bk)
      end
    end

    # Creates a `Parallelepiped` spanning from *vmin* to *vmax*.
    def self.new(vmin : Vec3, vmax : Vec3) : self
      size = {vmax.x - vmin.x, vmax.y - vmin.y, vmax.z - vmin.z}
      new(vmin, size)
    end

    # Creates a `Parallelepiped` with the given lengths placed at the
    # origin.
    def self.[](a : Number, b : Number, c : Number) : self
      new({a, b, c})
    end

    # Creates a cubic parallelepiped (*a* = *b* = *c* and *α* = *β* =
    # *γ* = 90°).
    def self.cubic(a : Number) : self
      new({a, a, a}, {90, 90, 90})
    end

    # Creates a hexagonal parallelepiped (*a* = *b*, *α* = *β* = 90°,
    # and *γ* = 120°).
    def self.hexagonal(a : Number, c : Number) : self
      new({a, a, c}, {90, 90, 120})
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

    # The length (in angstorms) of the first basis vector.
    def a : Float64
      bi.abs
    end

    # Returns the angle (in degrees) between the second and third basis
    # vectors.
    def alpha : Float64
      Spatial.angle bj, bk
    end

    # Returns the parallelepiped angles (alpha, beta, gamma) in degrees.
    def angles : NumberTriple
      {alpha, beta, gamma}
    end

    # The length (in angstorms) of the second basis vector.
    def b : Float64
      bj.abs
    end


    # The first basis vector.
    def bi : Vec3
      Vec3[*@basis[.., 0]]
    end

    # The second basis vector.
    def bj : Vec3
      Vec3[*@basis[.., 1]]
    end

    # The third basis vector.
    def bk : Vec3
      Vec3[*@basis[.., 2]]
    end

    # Returns the angle (in degrees) between the first and third basis
    # vectors.
    def beta : Float64
      Spatial.angle bi, bk
    end

    # The length (in angstorms) of the third basis vector.
    def c : Float64
      bk.abs
    end

    # Returns the vector in Cartesian coordinates equivalent to the
    # given fractional coordinates.
    def cart(vec : Vec3) : Vec3
      @basis * vec
    end

    # Returns the center of the parallelepiped.
    def center : Vec3
      @origin + (bi + bj + bk) * 0.5
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
      a.close_to?(b, 1e-15) && b.close_to?(c, 1e-15) && orthogonal?
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
      2.times do |di|
        2.times do |dj|
          2.times do |dk|
            yield @origin + bi * di + bj * dj + bk * dk
          end
        end
      end
    end

    # Returns the vector in fractional coordinates equivalent to the
    # given Cartesian coordinates.
    def fract(vec : Vec3) : Vec3
      inv_basis * vec
    end

    # Returns the angle (in degrees) between the first and second basis
    # vectors.
    def gamma : Float64
      Spatial.angle bi, bj
    end

    # Returns `true` if the parallelepiped is hexagonal (*a* = *b*, *α*
    # = *β* = 90°, and *γ* = 120°), else `false`.
    def hexagonal? : Bool
      a.close_to?(b, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        beta.close_to?(90, 1e-8) &&
        gamma.close_to?(120, 1e-8)
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
      # TODO: replace by an internal enum (xyz and triclinic) that is
      # updated on new basis to avoid doing this each time
      if bi.x? && bj.y? && bk.z?
        0 <= vec.x <= bi.x && 0 <= vec.y <= bj.y && 0 <= vec.z <= bk.z
      else
        vec = fract(vec).map &.round(Float64::DIGITS)
        0 <= vec.x <= 1 && 0 <= vec.y <= 1 && 0 <= vec.z <= 1
      end
    end

    def inspect(io : IO) : Nil
      format_spec = "%.#{PRINT_PRECISION}g"
      io << "#<" << self.class.name << ":0x"
      object_id.to_s(io, 16)
      io << " @origin=[ "
      io.printf format_spec, @origin.x
      io << ' '
      io.printf format_spec, @origin.y
      io << ' '
      io.printf format_spec, @origin.z
      io << " ], @basis=" << @basis << '>'
    end

    # Inverted matrix basis.
    private def inv_basis : Mat3
      @inv_basis ||= @basis.inv
    end

    # Returns `true` if the parallelepiped is monoclinic (*a* ≠ *c*, *α*
    # = *γ* = 90°, and *β* ≠ 90°), else `false`.
    def monoclinic? : Bool
      !a.close_to?(c, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        !beta.close_to?(90, 1e-8) &&
        gamma.close_to?(90, 1e-8)
    end

    # Returns `true` if the parallelepiped is orthogonal (*α* = *β* =
    # *γ* = 90°), else `false`.
    def orthogonal? : Bool
      alpha.close_to?(90, 1e-8) &&
        beta.close_to?(90, 1e-8) &&
        gamma.close_to?(90, 1e-8)
    end

    # Returns `true` if the parallelepiped is orthorhombic (*a* ≠ *b* ≠
    # *c* and *α* = *β* = *γ* = 90°), else `false`.
    def orthorhombic? : Bool
      !a.close_to?(b, 1e-15) &&
        !a.close_to?(c, 1e-15) &&
        !b.close_to?(c, 1e-15) &&
        orthogonal?
    end

    # Expands the extents of the parallelepiped by *padding* in every
    # direction. Note that its size is actually increased by `padding *
    # 2`.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[1, 5, 3], {10, 5, 12})
    # pld.center # => Vec3[6.0, 7.5, 9.0]
    # pld.pad(2.5)
    # pld.size   # => Size3[15, 10, 17]
    # pld.center # => Vec3[6.0, 7.5, 9.0]
    # ```
    def pad(padding : Number) : self
      raise ArgumentError.new "Negative padding" if padding < 0
      @origin -= (bi.resize(padding) + bj.resize(padding) + bk.resize(padding))
      padding *= 2
      @basis = Spatial::Mat3.basis(bi.pad(padding), bj.pad(padding), bk.pad(padding))
      self
    end

    # Returns `true` if the parallelepiped is rhombohedral (*a* = *b* =
    # *c* and *α* = *β* = *γ* ≠ 90°), else `false`.
    def rhombohedral? : Bool
      a.close_to?(b, 1e-15) &&
        a.close_to?(c, 1e-15) &&
        alpha.close_to?(beta, 1e-8) &&
        alpha.close_to?(gamma, 1e-8) &&
        !alpha.close_to?(90, 1e-8)
    end

    # Returns the lengths of the basis vectors.
    def size : Size3
      Size3[a, b, c]
    end

    # Returns `true` if the parallelepiped is tetragonal (*a* = *b* ≠
    # *c* and *α* = *β* = *γ* = 90°), else `false`.
    def tetragonal? : Bool
      a.close_to?(b, 1e-15) && !a.close_to?(c, 1e-15) && orthogonal?
    end

    # Translates the parallelepiped by *offset*.
    #
    # ```
    # pld = Parallelepiped.new(Vec3[-5, 1, 20], {10, 10, 10}, {90, 90, 120})
    # pld.translate Vec3[1, 2, 10]
    # pld.origin # => Vec3[-4.0, 3.0, 30.0]
    # ```
    def translate(offset : Vec3) : self
      @origin += offset
      self
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
      @origin + bi + bj + bk
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
  end

  struct Vec3
    # Returns vector's PBC image with respect to the parallelepiped.
    #
    # ```
    # pld = new Parallelepiped.new({2, 2, 3}, {90, 90, 120})
    # pld.i # => Vec3[2.0, 0.0, 0.0]
    # pld.j # => Vec3[-1, 1.732, 0.0]
    # pld.k # => Vec3[0.0, 0.0, 3.0]
    #
    # vec = Vec3[1, 1, 1.5]
    # vec.image(pld, 1, 0, 0) # => Vec3[3.0, 1.0, 1.5]
    # vec.image(pld, 0, 1, 0) # => Vec3[0.0, 2.732, 1.5]
    # vec.image(pld, 0, 0, 1) # => Vec3[1.0, 1.0, 4.5]
    # vec.image(pld, 1, 0, 1) # => Vec3[3.0, 1.0, 4.5]
    # vec.image(pld, 1, 1, 1) # => Vec3[2.0, 2.732, 4.5]
    # ```
    def image(pld : Parallelepiped, i : Int, j : Int, k : Int) : self
      self + pld.bi * i + pld.bj * j + pld.bk * k
    end

    # Returns a vector in Cartesian coordinates relative to *pld* (see
    # `Parallelepiped#cart`). The vector is assumed to be expressed in
    # fractional coordinates.
    def to_cart(pld : Parallelepiped) : self
      pld.cart self
    end

    # Returns a vector in fractional coordinates relative to *pld* (see
    # `Parallelepiped#fract`). The vector is assumed to be expressed in
    # Cartesian coordinates.
    def to_fract(pld : Parallelepiped) : self
      pld.fract self
    end

    # Returns the vector by wrapping into *pld*. The vector is assumed to
    # be expressed in Cartesian coordinates.
    def wrap(pld : Parallelepiped) : self
      pld.wrap self
    end

    # Returns the vector by wrapping into *pld* centered at *center*. The
    # vector is assumed to be expressed in Cartesian coordinates.
    def wrap(pld : Parallelepiped, around center : self) : self
      pld.wrap self, center
    end
  end
end
