module Chem::Spatial
  def self.angle(a : Vec3, b : Vec3) : Float64
    Math.atan2(a.cross(b).abs, a.dot(b)).degrees
  end

  def self.angle(a : Atom, b : Atom, c : Atom, cell : UnitCell? = nil) : Float64
    angle a.coords, b.coords, c.coords, cell
  end

  def self.angle(a : Vec3, b : Vec3, c : Vec3, cell : UnitCell? = nil) : Float64
    if cell
      a = a.wrap cell, around: b
      c = c.wrap cell, around: b
    end
    angle a - b, c - b
  end

  def self.dihedral(a : Vec3, b : Vec3, c : Vec3) : Float64
    ab = a.cross b
    angle = angle ab, b.cross(c)
    ab.dot(c) < 0 ? -angle : angle
  end

  def self.dihedral(a : Atom, b : Atom, c : Atom, d : Atom, *args, **options) : Float64
    dihedral a.coords, b.coords, c.coords, d.coords, *args, **options
  end

  def self.dihedral(a : Vec3,
                    b : Vec3,
                    c : Vec3,
                    d : Vec3,
                    cell : UnitCell? = nil) : Float64
    if cell
      a = a.wrap cell, around: b
      c = c.wrap cell, around: b
      d = d.wrap cell, around: c
    end
    dihedral b - a, c - b, d - c
  end

  def self.distance(*args, **options) : Float64
    Math.sqrt squared_distance(*args, **options)
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

  def self.improper(a : Atom, b : Atom, c : Atom, d : Atom, *args, **options) : Float64
    improper a.coords, b.coords, c.coords, d.coords, *args, **options
  end

  def self.improper(a : Vec3,
                    b : Vec3,
                    c : Vec3,
                    d : Vec3,
                    cell : UnitCell? = nil) : Float64
    dihedral b, a, c, d, cell
  end

  def self.squared_distance(a : Atom, b : Atom, cell : UnitCell? = nil) : Float64
    squared_distance a.coords, b.coords, cell
  end

  @[AlwaysInline]
  def self.squared_distance(a : Vec3, b : Vec3, cell : UnitCell? = nil) : Float64
    b = b.wrap cell, around: a if cell
    (a.x - b.x)**2 + (a.y - b.y)**2 + (a.z - b.z)**2
  end
end
