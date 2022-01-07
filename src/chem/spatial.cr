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
end
