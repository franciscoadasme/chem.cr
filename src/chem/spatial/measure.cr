module Chem::Spatial
  def angle(v1 : Vector, v2 : Vector) : Float64
    Math.atan2(v1.cross(v2).size, v1.dot(v2)).degrees
  end

  def angle(a1 : Atom, a2 : Atom, a3 : Atom) : Float64
    angle a1.coords, a2.coords, a3.coords
  end

  def angle(p1 : Vector, p2 : Vector, p3 : Vector) : Float64
    angle p2 - p1, p3 - p2
  end

  def dihedral(v1 : Vector, v2 : Vector, v3 : Vector) : Float64
    v12 = v1.cross v2
    angle = angle v12, v2.cross(v3)
    v12.dot(v3) < 0 ? -angle : angle
  end

  def dihedral(a1 : Atom, a2 : Atom, a3 : Atom, a4 : Atom) : Float64
    dihedral a1.coords, a2.coords, a3.coords, a4.coords
  end

  def dihedral(p1 : Vector, p2 : Vector, p3 : Vector, p4 : Vector) : Float64
    dihedral p2 - p1, p3 - p2, p4 - p3
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
