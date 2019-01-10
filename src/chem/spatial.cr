require "./spatial/*"

module Chem::Spatial
  extend self

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

  def distance(a1 : Atom, a2 : Atom) : Float64
    distance a1.coords, a2.coords
  end

  def distance(p1 : Vector, p2 : Vector) : Float64
    Math.sqrt squared_distance(p1, p2)
  end

  def squared_distance(a1 : Atom, a2 : Atom) : Float64
    squared_distance a1.coords, a2.coords
  end

  @[AlwaysInline]
  def squared_distance(p1 : Vector, p2 : Vector) : Float64
    (p1.x - p2.x)**2 + (p1.y - p2.y)**2 + (p1.z - p2.z)**2
  end
end
