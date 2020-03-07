module Chem::Spatial
  def angle(a : Vector, b : Vector) : Float64
    Math.atan2(a.cross(b).size, a.dot(b)).degrees
  end

  def angle(a : Atom, b : Atom, c : Atom, *args, **options) : Float64
    angle a.coords, b.coords, c.coords, *args, **options
  end

  def angle(a : Vector, b : Vector, c : Vector) : Float64
    angle a - b, c - b
  end

  def angle(a : Vector, b : Vector, c : Vector, lattice : Lattice) : Float64
    angle a.wrap(lattice, around: b), b, c.wrap(lattice, around: b)
  end

  def dihedral(a : Vector, b : Vector, c : Vector) : Float64
    ab = a.cross b
    angle = angle ab, b.cross(c)
    ab.dot(c) < 0 ? -angle : angle
  end

  def dihedral(a : Atom, b : Atom, c : Atom, d : Atom) : Float64
    dihedral a.coords, b.coords, c.coords, d.coords
  end

  def dihedral(a : Vector, b : Vector, c : Vector, d : Vector) : Float64
    dihedral b - a, c - b, d - c
  end

  def distance(*args, **options) : Float64
    Math.sqrt squared_distance(*args, **options)
  end

  def distance(q1 : Quaternion, q2 : Quaternion) : Float64
    # 2 * Math.acos q1.dot(q2)
    Math.acos 2 * q1.dot(q2)**2 - 1
  end

  def squared_distance(a1 : Atom, a2 : Atom, *args, **options) : Float64
    squared_distance a1.coords, a2.coords, *args, **options
  end

  @[AlwaysInline]
  def squared_distance(a : Vector, b : Vector) : Float64
    (a.x - b.x)**2 + (a.y - b.y)**2 + (a.z - b.z)**2
  end

  @[AlwaysInline]
  def squared_distance(a : Vector, b : Vector, lattice : Lattice) : Float64
    squared_distance a, b.wrap(lattice, around: a)
  end
end
