module Chem
  # A parallel epipedal unit cell defined by three vectors (basis).
  #
  # It is internally represented by a 3x3 matrix, where each column
  # correspond to a basis vector (see `Spatial::Mat3.basis`), which
  # coordinates are expressed in Cartesian space (angstroms). In this
  # way, the basis matrix can be used to transform from Cartesian to
  # fractional coordinates, and viceversa, by matrix multiplication (see
  # `#cart` and `#fract`).
  class UnitCell
    # Matrix containing the basis vectors.
    getter basis : Spatial::Mat3

    # Caches the inverse matrix for coordinate conversion.
    @inv_basis : Spatial::Mat3?

    # Creates a new `UnitCell` with the given basis.
    def initialize(@basis : Spatial::Mat3)
    end

    # Returns a new `UnitCell` with the given basis vectors.
    def self.new(i : Spatial::Vec3, j : Spatial::Vec3, k : Spatial::Vec3) : self
      UnitCell.new Spatial::Mat3.basis(i, j, k)
    end

    # Returns a new `UnitCell` with the given unit cell parameters
    # (lengths in angstroms and angles in degrees). Raises
    # `ArgumentError` if any of the lengths or angles is negative.
    #
    # NOTE: The first basis vector will be aligned to the X axis and the
    # second basis vector will lie in the XY plane.
    def self.new(size : NumberTriple | Size3,
                 angles : NumberTriple = {90, 90, 90}) : self
      raise ArgumentError.new("Negative size") if !size.is_a?(Size3) && size.any?(&.negative?)
      raise ArgumentError.new("Negative angle") if angles.any?(&.negative?)
      if angles.all?(&.close_to?(90))
        basis = Mat3.diagonal size[0], size[1], size[2]
      else
        cos_alpha = Math.cos angles[0].radians
        cos_beta = Math.cos angles[1].radians
        cos_gamma = Math.cos angles[2].radians
        sin_gamma = Math.sin angles[2].radians

        kx = size[2] * cos_beta
        ky = size[2] * (cos_alpha - cos_beta * cos_gamma) / sin_gamma
        kz = Math.sqrt size[2]**2 - kx**2 - ky**2

        # column-major order
        basis = Mat3[
          {size[0], size[1] * cos_gamma, kx},
          {0, size[1] * sin_gamma, ky},
          {0, 0, kz},
        ]
      end
      UnitCell.new(basis)
    end

    # Returns a cubic unit cell (*a* = *b* = *c* and *α* = *β* = *γ* =
    # 90°).
    def self.cubic(a : Number) : self
      UnitCell.new({a, a, a}, {90, 90, 90})
    end

    # Returns a hexagonal unit cell (*a* = *b*, *α* = *β* = 90°, and *γ*
    # = 120°).
    def self.hexagonal(a : Number, c : Number) : self
      UnitCell.new({a, a, c}, {90, 90, 120})
    end

    # Returns a monoclinic unit cell (*a* ≠ *c*, *α* = *γ* = 90°, and
    # *β* ≠ 90°).
    def self.monoclinic(a : Number, c : Number, beta : Number) : self
      UnitCell.new({a, a, c}, {90, beta, 90})
    end

    # Returns an orthorhombic unit cell (*a* ≠ *b* ≠ *c* and *α* = *β* =
    # *γ* = 90°).
    def self.orthorhombic(a : Number, b : Number, c : Number) : self
      UnitCell.new({a, b, c}, {90, 90, 90})
    end

    # Returns an rhombohedral unit cell (*a* = *b* = *c* and *α* = *β* =
    # *γ* ≠ 90°).
    def self.rhombohedral(a : Number, alpha : Number) : self
      UnitCell.new({a, a, a}, {alpha, alpha, alpha})
    end

    # Returns an tetragonal unit cell (*a* = *b* ≠ *c* and *α* = *β* =
    # *γ* = 90°).
    def self.tetragonal(a : Number, c : Number) : self
      UnitCell.new({a, a, c}, {90, 90, 90})
    end

    # Returns a unit cell with the basis vectors multiplied by *value*.
    def *(value : Number) : self
      UnitCell.new i * value, j * value, k * value
    end

    # The length (in angstorms) of the first basis vector.
    def a : Float64
      i.abs
    end

    # :ditto:
    def a=(value : Float64) : Float64
      @basis = Spatial::Mat3.basis i.resize(value), j, k
      value
    end

    # Returns the angle (in degrees) between the second and third basis
    # vectors.
    def alpha : Float64
      Spatial.angle j, k
    end

    # Returns the unit cell angles (alpha, beta, gamma) in degrees.
    def angles : NumberTriple
      {alpha, beta, gamma}
    end

    # The length (in angstorms) of the second basis vector.
    def b : Float64
      j.abs
    end

    # :ditto:
    def b=(value : Float64) : Float64
      @basis = Spatial::Mat3.basis i, j.resize(value), k
      value
    end

    # Returns the angle (in degrees) between the first and third basis
    # vectors.
    def beta : Float64
      Spatial.angle i, k
    end

    # Returns the bounds of the unit cell.
    def bounds : Spatial::Bounds
      Spatial::Bounds.new Spatial::Vec3.zero, @basis
    end

    # The length (in angstorms) of the third basis vector.
    def c : Float64
      k.abs
    end

    # :ditto:
    def c=(value : Float64) : Float64
      @basis = Spatial::Mat3.basis i, j, k.resize(value)
      value
    end

    # Returns the vector in Cartesian coordinates equivalent to the
    # given fractional coordinates.
    def cart(vec : Spatial::Vec3) : Spatial::Vec3
      @basis * vec
    end

    # Returns `true` if the unit cell is cubic (*a* = *b* = *c* and *α*
    # = *β* = *γ* = 90°), else `false`.
    def cubic? : Bool
      a.close_to?(b, 1e-15) && b.close_to?(c, 1e-15) && orthogonal?
    end

    # Returns the vector in fractional coordinates equivalent to the
    # given Cartesian coordinates.
    def fract(vec : Spatial::Vec3) : Spatial::Vec3
      inv_basis * vec
    end

    # Returns the angle (in degrees) between the first and second basis
    # vectors.
    def gamma : Float64
      Spatial.angle i, j
    end

    # Returns `true` if the unit cell is hexagonal (*a* = *b*, *α* = *β*
    # = 90°, and *γ* = 120°), else `false`.
    def hexagonal? : Bool
      a.close_to?(b, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        beta.close_to?(90, 1e-8) &&
        gamma.close_to?(120, 1e-8)
    end

    # The first basis vector.
    def i : Spatial::Vec3
      Spatial::Vec3[*@basis[.., 0]]
    end

    # :ditto:
    def i=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Mat3.basis vec, j, k
      vec
    end

    def inspect(io : IO) : Nil
      io << "<UnitCell " << i << ", " << j << ", " << k << '>'
    end

    # The second basis vector.
    def j : Spatial::Vec3
      Spatial::Vec3[*@basis[.., 1]]
    end

    # :ditto:
    def j=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Mat3.basis i, vec, k
      vec
    end

    # The third basis vector.
    def k : Spatial::Vec3
      Spatial::Vec3[*@basis[.., 2]]
    end

    # :ditto:
    def k=(vec : Spatial::Vec3) : Spatial::Vec3
      @basis = Spatial::Mat3.basis i, j, vec
      vec
    end

    # Returns `true` if the unit cell is monoclinic (*a* ≠ *c*, *α* =
    # *γ* = 90°, and *β* ≠ 90°), else `false`.
    def monoclinic? : Bool
      !a.close_to?(c, 1e-15) &&
        alpha.close_to?(90, 1e-8) &&
        !beta.close_to?(90, 1e-8) &&
        gamma.close_to?(90, 1e-8)
    end

    # Returns `true` if the unit cell is orthogonal (*α* = *β* = *γ* =
    # 90°), else `false`.
    def orthogonal? : Bool
      alpha.close_to?(90, 1e-8) &&
        beta.close_to?(90, 1e-8) &&
        gamma.close_to?(90, 1e-8)
    end

    # Returns `true` if the unit cell is orthorhombic (*a* ≠ *b* ≠ *c*
    # and *α* = *β* = *γ* = 90°), else `false`.
    def orthorhombic? : Bool
      !a.close_to?(b, 1e-15) &&
        !a.close_to?(c, 1e-15) &&
        !b.close_to?(c, 1e-15) &&
        orthogonal?
    end

    # Returns `true` if the unit cell is rhombohedral (*a* = *b* = *c*
    # and *α* = *β* = *γ* ≠ 90°), else `false`.
    def rhombohedral? : Bool
      a.close_to?(b, 1e-15) &&
        a.close_to?(c, 1e-15) &&
        alpha.close_to?(beta, 1e-8) &&
        alpha.close_to?(gamma, 1e-8) &&
        !alpha.close_to?(90, 1e-8)
    end

    # Returns the lengths of the basis vectors.
    def size : Spatial::Size3
      Spatial::Size3[a, b, c]
    end

    # Returns `true` if the unit cell is tetragonal (*a* = *b* ≠ *c* and
    # *α* = *β* = *γ* = 90°), else `false`.
    def tetragonal? : Bool
      a.close_to?(b, 1e-15) && !a.close_to?(c, 1e-15) && orthogonal?
    end

    # Returns `true` if the unit cell is triclinic (not orthogonal,
    # hexagonal, monoclinic, nor rhombohedral), else `false`.
    def triclinic? : Bool
      !orthogonal? && !hexagonal? && !monoclinic? && !rhombohedral?
    end

    # Returns the volume of the unit cell.
    def volume : Float64
      @basis.det
    end

    # Returns the vector by wrapping into the primary unit cell. The
    # vector is assumed to be expressed in Cartesian coordinates.
    def wrap(vec : Spatial::Vec3) : Spatial::Vec3
      cart fract(vec).wrap
    end

    # Returns the vector by wrapping into the primary unit cell centered
    # at *center*. The vector is assumed to be expressed in Cartesian
    # coordinates.
    def wrap(vec : Spatial::Vec3, around center : Spatial::Vec3) : Spatial::Vec3
      cart fract(vec).wrap(fract(center))
    end

    # Inverted matrix basis.
    private def inv_basis : Spatial::Mat3
      @inv_basis ||= @basis.inv
    end
  end
end

struct Chem::Spatial::Vec3
  # Returns vector's PBC image with respect to `cell`
  #
  # ```
  # lat = UnitCell.new S[2, 2, 3], 90, 90, 120
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
  def image(cell : UnitCell, i : Int, j : Int, k : Int) : self
    self + cell.i * i + cell.j * j + cell.k * k
  end

  # Returns a vector in Cartesian coordinates relative to *cell* (see
  # `UnitCell#cart`). The vector is assumed to be expressed in
  # fractional coordinates.
  def to_cart(cell : UnitCell) : self
    cell.cart self
  end

  # Returns a vector in fractional coordinates relative to *cell* (see
  # `UnitCell#fract`). The vector is assumed to be expressed in
  # Cartesian coordinates.
  def to_fract(cell : UnitCell) : self
    cell.fract self
  end

  # Returns the vector by wrapping into *cell*. The vector is assumed to
  # be expressed in Cartesian coordinates.
  def wrap(cell : UnitCell) : self
    cell.wrap self
  end

  # Returns the vector by wrapping into *cell* centered at *center*. The
  # vector is assumed to be expressed in Cartesian coordinates.
  def wrap(cell : UnitCell, around center : self) : self
    cell.wrap self, center
  end
end