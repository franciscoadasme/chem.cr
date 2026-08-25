require "./spatial/transform"
require "./spatial/size3"
require "./spatial/vec3"
require "./spatial/mat3"
require "./spatial/direction"

require "./spatial/grid"
require "./spatial/quat"
require "./spatial/parallelepiped"

require "./spatial/positions3"
require "./spatial/positions3_proxy"
require "./spatial/kdtree"
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

  def self.angle(a : Atom, b : Atom, c : Atom) : Float64
    angle a.pos, b.pos, c.pos
  end

  def self.angle(a : Vec3, b : Vec3, c : Vec3) : Float64
    (a - b).angle(c - b).degrees
  end

  def self.angle(cell : Parallelepiped, a : Atom, b : Atom, c : Atom) : Float64
    angle cell, a.pos, b.pos, c.pos
  end

  def self.angle(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3) : Float64
    angle cell.wrap(a, around: b), b, cell.wrap(c, around: b)
  end

  def self.dihedral(a : Vec3, b : Vec3, c : Vec3) : Float64
    ab = a.cross b
    angle = ab.angle(b.cross(c)).degrees
    ab.dot(c) < 0 ? -angle : angle
  end

  def self.dihedral(a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    dihedral a.pos, b.pos, c.pos, d.pos
  end

  def self.dihedral(a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral b - a, c - b, d - c
  end

  def self.dihedral(cell : Parallelepiped, a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    dihedral cell, a.pos, b.pos, c.pos, d.pos
  end

  def self.dihedral(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    a = cell.wrap a, around: b
    c = cell.wrap c, around: b
    d = cell.wrap d, around: c
    dihedral a, b, c, d
  end

  def self.distance(a : Vec3, b : Vec3) : Float64
    a.distance(b)
  end

  def self.distance(a : Atom, b : Atom) : Float64
    a.pos.distance(b.pos)
  end

  def self.distance(cell : Parallelepiped, a : Atom, b : Atom) : Float64
    distance cell, a.pos, b.pos
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

  def self.distance2(a : Vec3, b : Vec3) : Float64
    a.distance2(b)
  end

  def self.distance2(a : Atom, b : Atom) : Float64
    a.pos.distance2 b.pos
  end

  def self.distance2(cell : Parallelepiped, a : Atom, b : Atom) : Float64
    distance2 cell, a.pos, b.pos
  end

  def self.distance2(cell : Parallelepiped, a : Vec3, b : Vec3) : Float64
    a.distance2 cell.wrap(b, around: a)
  end

  def self.improper(a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    improper a.pos, b.pos, c.pos, d.pos
  end

  def self.improper(a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral b, a, c, d
  end

  def self.improper(cell : Parallelepiped, a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    improper cell, a.pos, b.pos, c.pos, d.pos
  end

  def self.improper(cell : Parallelepiped, a : Vec3, b : Vec3, c : Vec3, d : Vec3) : Float64
    dihedral cell, b, a, c, d
  end

  # Returns a coordinate list for *obj*.
  #
  # Accepts coordinate arrays and anything that exposes atoms or a
  # `pos` proxy (`AtomView`, `Structure`, residue/chain views, and
  # `Positions3Proxy`).
  def self.coords(pos : Indexable(Vec3)) : Indexable(Vec3)
    pos
  end

  # :ditto:
  def self.coords(atoms : AtomView) : Indexable(Vec3)
    atoms.pos
  end

  # :ditto:
  def self.coords(obj : Structure) : Indexable(Vec3)
    obj.pos
  end

  # :ditto:
  def self.coords(obj : Residue | ResidueView | Chain | ChainView) : Indexable(Vec3)
    obj.atoms.pos
  end

  # Returns the root mean square deviation (RMSD) in Å between two
  # coordinate sets.
  #
  # The RMSD is the average Euclidean distance between corresponding
  # coordinates in *pos* and *ref_pos*. If *minimize* is `true`, the
  # coordinates are superimposed first using the QCP method (see
  # `.qcp`). *weights*, if given, determine the relative contribution
  # of each coordinate.
  #
  # Raises `ArgumentError` if the two sets have different sizes or are
  # empty.
  #
  # NOTE: Prefer `AtomView#rmsd` or `Positions3Proxy#rmsd` when
  # coordinates belong to atoms, especially if symmetry-corrected RMSD
  # is needed.
  def self.rmsd(
    pos : Indexable(Vec3),
    ref_pos : Indexable(Vec3),
    *,
    weights : Indexable(Float64)? = nil,
    minimize : Bool = false,
  ) : Float64
    raise ArgumentError.new("Incompatible coordinates") if pos.size != ref_pos.size
    raise ArgumentError.new("Empty coordinates") if pos.empty?
    if weights
      raise ArgumentError.new("Incompatible coordinates") if weights.size != pos.size
    end

    if minimize
      pos = pos.map(&.itself)
      ref_pos = ref_pos.map(&.itself)
      if weights
        center = pos.average(weights)
        pos.map! &.-(center)
        center = ref_pos.average(weights)
        ref_pos.map! &.-(center)
        _, rmsd = qcp(pos, ref_pos, weights.map(&./(weights.mean)))
        rmsd
      else
        center = pos.mean
        pos.map! &.-(center)
        center = ref_pos.mean
        ref_pos.map! &.-(center)
        _, rmsd = qcp(pos, ref_pos)
        rmsd
      end
    elsif weights
      Math.sqrt((0...pos.size).average(weights) do |i|
        pos.unsafe_fetch(i).distance2 ref_pos.unsafe_fetch(i)
      end)
    else
      Math.sqrt((0...pos.size).mean do |i|
        pos.unsafe_fetch(i).distance2 ref_pos.unsafe_fetch(i)
      end)
    end
  end

  # :ditto:
  def self.rmsd(
    pos,
    ref_pos,
    *,
    weights : Indexable(Float64)? = nil,
    minimize : Bool = false,
  ) : Float64
    rmsd coords(pos), coords(ref_pos), weights: weights, minimize: minimize
  end
end
