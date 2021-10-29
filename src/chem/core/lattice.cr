module Chem
  # A parallel epipedal unit cell defined by three vectors (basis).
  #
  # It is internally represented by a 3x3 matrix, where each column
  # correspond to a basis vector (see `Spatial::Mat3.basis`), which
  # coordinates are expressed in Cartesian space (angstroms). In this
  # way, the basis matrix can be used to transform from Cartesian to
  # fractional coordinates, and viceversa, by matrix multiplication (see
  # `#cart` and `#fract`).
  class Lattice
    # Matrix containing the basis vectors.
    getter basis : Spatial::Mat3

    # Caches the inverse matrix for coordinate conversion.
    @inv_basis : Spatial::Mat3?

    # Creates a new `Lattice` with the given basis.
    def initialize(@basis : Spatial::Mat3)
    end

    # Returns a new `Lattice` with the given basis vectors.
    def self.new(i : Vec3, j : Vec3, k : Vec3) : self
      Lattice.new Spatial::Mat3.basis(i, j, k)
    end

    # Returns a new `Lattice` with the given unit cell parameters
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
      Lattice.new(basis)
    end

    # Returns a cubic lattice (*a* = *b* = *c* and *α* = *β* = *γ* =
    # 90°).
    def self.cubic(a : Number) : self
      Lattice.new({a, a, a}, {90, 90, 90})
    end

    # Returns a hexagonal lattice (*a* = *b*, *α* = *β* = 90°, and *γ* =
    # 120°).
    def self.hexagonal(a : Number, c : Number) : self
      Lattice.new({a, a, c}, {90, 90, 120})
    end

    # Returns a monoclinic lattice (*a* ≠ *c*, *α* = *γ* = 90°, and *β*
    # ≠ 90°).
    def self.monoclinic(a : Number, c : Number, beta : Number) : self
      Lattice.new({a, a, c}, {90, beta, 90})
    end

    # Returns an orthorhombic lattice (*a* ≠ *b* ≠ *c* and *α* = *β* =
    # *γ* = 90°).
    def self.orthorhombic(a : Number, b : Number, c : Number) : self
      Lattice.new({a, b, c}, {90, 90, 90})
    end

    # Returns an rhombohedral lattice (*a* = *b* = *c* and *α* = *β* =
    # *γ* ≠ 90°).
    def self.rhombohedral(a : Number, alpha : Number) : self
      Lattice.new({a, a, a}, {alpha, alpha, alpha})
    end

    # Returns an tetragonal lattice (*a* = *b* ≠ *c* and *α* = *β* = *γ*
    # = 90°).
    def self.tetragonal(a : Number, c : Number) : self
      Lattice.new({a, a, c}, {90, 90, 90})
    end

    # Returns a lattice with the basis vectors multiplied by *value*.
    def *(value : Number) : self
      Lattice.new i * value, j * value, k * value
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
      Spatial::Bounds.new Spatial::Vec3.zero, Spatial::Basis.new(i, j, k)
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
    def cart(vec : Vec3) : Vec3
      @basis * vec
    end

    # Returns `true` if the lattice is a cube (cell lengths are equal
    # and cell angles are close to 90 degrees), else `false`.
    def cubic? : Bool
      a.close_to?(b) && b.close_to?(c) && orthogonal?
    end

    # Returns the vector in fractional coordinates equivalent to the
    # given Cartesian coordinates.
    def fract(vec : Vec3) : Vec3
      inv_basis * vec
    end

    # Returns the angle (in degrees) between the first and second basis
    # vectors.
    def gamma : Float64
      Spatial.angle i, j
    end

    # Returns `true` if the lattice is hexagonal (*a* is equal to *b*
    # and cell angles are close to 90, 90, 120 degrees), else `false`.
    def hexagonal? : Bool
      a.close_to?(b) && alpha.close_to?(90) && beta.close_to?(90) && gamma.close_to?(120)
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
      io << "<Lattice " << i << ", " << j << ", " << k << '>'
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

    # Returns `true` if the lattice is monoclinic (*a* is not equal to
    # *c*, *alpha* and *gamma* are close to 90 degrees and *beta* is
    # different from 90 degrees), else `false`.
    def monoclinic? : Bool
      !a.close_to?(c) && alpha.close_to?(90) && !beta.close_to?(90) && gamma.close_to?(90)
    end

    # Returns `true` if the lattice is orthogonal (cell angles are close
    # to 90 degrees), else `false`.
    def orthogonal? : Bool
      alpha.close_to?(90) && beta.close_to?(90) && gamma.close_to?(90)
    end

    # Returns `true` if the lattice is orthorhombic (cell lengths are
    # not equal and cell angles are close to 90 degrees), else `false`.
    def orthorhombic? : Bool
      !a.close_to?(b) && !a.close_to?(c) && !b.close_to?(c) && orthogonal?
    end

    # Returns the lengths of the basis vectors.
    def size : Size3
      Size3[a, b, c]
    end

    # Returns `true` if the lattice is tetragonal (*a* is equal to *b*
    # but different than *c*, and cell angles are close to 90 degrees),
    # else `false`.
    def tetragonal? : Bool
      a.close_to?(b) && !b.close_to?(c) && orthogonal?
    end

    # Returns `true` if the lattice is triclinic (cell lengths are
    # different and cell angles are different than 90 degrees), else
    # `false`.
    def triclinic? : Bool
      !orthogonal? && !monoclinic? && !hexagonal?
    end

    # Inverted matrix basis.
    private def inv_basis : Spatial::Mat3
      @inv_basis ||= @basis.inv
    end
  end
end
