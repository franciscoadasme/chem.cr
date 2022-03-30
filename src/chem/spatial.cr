require "./spatial/affine"
require "./spatial/size3"
require "./spatial/vec3"
require "./spatial/mat3"

require "./spatial/grid"
require "./spatial/quat"
require "./spatial/parallelepiped"

require "./spatial/coordinates_proxy"
require "./spatial/kdtree"
require "./spatial/pbc"
require "./spatial/qcp"

module Chem::Spatial
  # TODO: Move aliases to Chem
  alias FloatTriple = Tuple(Float64, Float64, Float64)
  alias NumberTriple = Tuple(Number::Primitive, Number::Primitive, Number::Primitive)

  # :nodoc:
  PRINT_PRECISION = 7

  class Error < Exception; end

  class NotPeriodicError < Error
    def initialize(message = "Coordinates are not periodic")
      super(message)
    end
  end

  def self.angle(a : Vec3, b : Vec3) : Float64
    Math.atan2(a.cross(b).abs, a.dot(b)).degrees
  end

  def self.angle(a : Atom, b : Atom, c : Atom) : Float64
    angle a.coords, b.coords, c.coords
  end

  def self.angle(a : Vec3, b : Vec3, c : Vec3) : Float64
    angle a - b, c - b
  end

  def self.angle(cell : Parallelepiped, a : Atom, b : Atom, c : Atom) : Float64
    angle cell, a.coords, b.coords, c.coords
  end

  def self.angle(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3) : Float64
    angle cell.wrap(a, around: b), b, cell.wrap(c, around: b)
  end

  def self.dihedral(a : Vec3, b : Vec3, c : Vec3) : Float64
    ab = a.cross b
    angle = angle ab, b.cross(c)
    ab.dot(c) < 0 ? -angle : angle
  end

  def self.dihedral(a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    dihedral a.coords, b.coords, c.coords, d.coords
  end

  def self.dihedral(a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral b - a, c - b, d - c
  end

  def self.dihedral(cell : Parallelepiped, a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    dihedral cell, a.coords, b.coords, c.coords, d.coords
  end

  def self.dihedral(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    a = cell.wrap a, around: b
    c = cell.wrap c, around: b
    d = cell.wrap d, around: c
    dihedral a, b, c, d
  end

  def self.distance(a : Atom, b : Atom) : Float64
    distance a.coords, b.coords
  end

  @[AlwaysInline]
  def self.distance(a : Vec3, b : Vec3) : Float64
    Math.sqrt distance2(a, b)
  end

  def self.distance(cell : Parallelepiped, a : Atom, b : Atom) : Float64
    distance cell, a.coords, b.coords
  end

  def self.distance(cell : Parallelepiped, a : Vec3, b : Vec3) : Float64
    Math.sqrt distance2(cell, a, b)
  end

  # Returns the distance between two quaternions.
  #
  # It uses the formula `acos(2 * p·q^2 - 1)`, which returns the angular
  # distance (0 to π) between the orientations represented by the
  # two quaternions. Taken from
  # [https://math.stackexchange.com/a/90098](https://math.stackexchange.com/a/90098).
  def self.distance(q1 : Quat, q2 : Quat) : Float64
    # 2 * Math.acos q1.dot(q2)
    Math.acos 2 * q1.dot(q2)**2 - 1
  end

  def self.distance2(a : Atom, b : Atom) : Float64
    distance2 a.coords, b.coords
  end

  @[AlwaysInline]
  def self.distance2(a : Vec3, b : Vec3) : Float64
    (a.x - b.x)**2 + (a.y - b.y)**2 + (a.z - b.z)**2
  end

  def self.distance2(cell : Parallelepiped, a : Atom, b : Atom) : Float64
    distance2 cell, a.coords, b.coords
  end

  def self.distance2(cell : Parallelepiped, a : Vec3, b : Vec3) : Float64
    distance2 a, cell.wrap(b, around: a)
  end

  def self.improper(a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    improper a.coords, b.coords, c.coords, d.coords
  end

  def self.improper(a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral b, a, c, d
  end

  def self.improper(cell : Parallelepiped, a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    improper cell, a.coords, b.coords, c.coords, d.coords
  end

  def self.improper(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral cell, b, a, c, d
  end

  # Returns the weighted root mean square deviation (RMSD) in Å between
  # two sets of coordinates *pos* and *ref_pos*.
  #
  # The RMSD is defined as the weighted average Euclidean distance
  # between the two coordinates sets *A* and *B*. The *weights* (e.g.,
  # atom masses) determine the relative weights of each coordinate when
  # calculating the RMSD.
  #
  # If the minimum RMSD is desired (*minimize* is `true`), the RMSD will
  # be computed using the quaternion-based characteristic polynomial
  # (QCP) method (refer to `.qcp`). This method superimpose *pos* onto
  # *ref_pos* by computing the optimal rotation between the two
  # coordinate sets before calculating the RMSD.
  def self.rmsd(
    pos : CoordinatesProxy,
    ref_pos : CoordinatesProxy,
    weights : Indexable(Float64),
    minimize : Bool = false
  ) : Float64
    pos = pos.to_a         # FIXME: avoid copying coordinates
    ref_pos = ref_pos.to_a # FIXME: avoid copying coordinates
    raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size

    if minimize
      # requires that the coordinates are centered at origin
      # FIXME: replace by pos.dup.center_at_origin(weights)
      center = pos.average(weights)
      pos.map! &.-(center)
      center = ref_pos.average(weights)
      ref_pos.map! &.-(center)

      # weights should be relative to the mean
      weight_mean = weights.mean
      weights.map! &./(weight_mean)

      Spatial.qcp(pos, ref_pos, weights)
    else
      Math.sqrt((0...pos.size).average(weights) do |i|
        Spatial.distance2 pos.unsafe_fetch(i), ref_pos.unsafe_fetch(i)
      end)
    end
  end

  # Returns the root mean square deviation (RMSD) in Å between two sets
  # of coordinates *pos* and *ref_pos*.
  #
  # The RMSD is defined as the average Euclidean distance between the
  # two coordinates sets *A* and *B*.
  #
  # If the minimum RMSD is desired (*minimize* is `true`), the RMSD will
  # be computed using the quaternion-based characteristic polynomial
  # (QCP) method (refer to `.qcp`). This method superimpose *pos* onto
  # *ref_pos* by computing the optimal rotation between the two
  # coordinate sets before calculating the RMSD.
  def self.rmsd(
    pos : CoordinatesProxy,
    ref_pos : CoordinatesProxy,
    minimize : Bool = false
  ) : Float64
    pos = pos.to_a         # FIXME: avoid copying coordinates
    ref_pos = ref_pos.to_a # FIXME: avoid copying coordinates

    if minimize
      # requires that the coordinates are centered at origin
      # FIXME: replace by pos.dup.center_at_origin
      center = pos.mean
      pos.map! &.-(center)
      center = ref_pos.mean
      ref_pos.map! &.-(center)
      Spatial.qcp pos, ref_pos
    else
      Math.sqrt((0...pos.size).mean do |i|
        Spatial.distance2 pos.unsafe_fetch(i), ref_pos.unsafe_fetch(i)
      end)
    end
  end
end

module Chem::Spatial
  # Superimposes *atoms* onto *other*. Delegates to
  # `CoordinatesProxy.align_to`.
  def self.align(
    atoms : AtomCollection | CoordinatesProxy,
    ref_pos : AtomCollection | CoordinatesProxy
  )
    # TODO: add option to ensure to atom equivalence
    atoms = atoms.coords unless atoms.is_a?(CoordinatesProxy)
    ref_pos = ref_pos.coords unless ref_pos.is_a?(CoordinatesProxy)
    atoms.align_to ref_pos
  end

  # Returns the root mean square deviation (RMSD) in Å between two atom
  # collections. This is a convenience overload so arguments are
  # forwarded to specific `.rmsd` methods.
  def self.rmsd(
    atoms : AtomCollection | CoordinatesProxy,
    other : AtomCollection | CoordinatesProxy,
    *args,
    **options
  )
    # TODO: add option to ensure to atom equivalence
    atoms = atoms.coords unless atoms.is_a?(CoordinatesProxy)
    other = other.coords unless other.is_a?(CoordinatesProxy)
    rmsd atoms, other, *args, **options
  end
end
