module Chem::Spatial
  def angle(a : Vec3, b : Vec3) : Float64
    Math.atan2(a.cross(b).size, a.dot(b)).degrees
  end

  def angle(a : Atom, b : Atom, c : Atom, lattice : Lattice? = nil) : Float64
    angle a.coords, b.coords, c.coords, lattice
  end

  def angle(a : Vec3, b : Vec3, c : Vec3, lattice : Lattice? = nil) : Float64
    if lattice
      a = a.wrap lattice, around: b
      c = c.wrap lattice, around: b
    end
    angle a - b, c - b
  end

  def dihedral(a : Vec3, b : Vec3, c : Vec3) : Float64
    ab = a.cross b
    angle = angle ab, b.cross(c)
    ab.dot(c) < 0 ? -angle : angle
  end

  def dihedral(a : Atom, b : Atom, c : Atom, d : Atom, *args, **options) : Float64
    dihedral a.coords, b.coords, c.coords, d.coords, *args, **options
  end

  def dihedral(a : Vec3,
               b : Vec3,
               c : Vec3,
               d : Vec3,
               lattice : Lattice? = nil) : Float64
    if lattice
      a = a.wrap lattice, around: b
      c = c.wrap lattice, around: b
      d = d.wrap lattice, around: c
    end
    dihedral b - a, c - b, d - c
  end

  def distance(*args, **options) : Float64
    Math.sqrt squared_distance(*args, **options)
  end

  def distance(q1 : Quat, q2 : Quat) : Float64
    # 2 * Math.acos q1.dot(q2)
    Math.acos 2 * q1.dot(q2)**2 - 1
  end

  def improper(a : Atom, b : Atom, c : Atom, d : Atom, *args, **options) : Float64
    improper a.coords, b.coords, c.coords, d.coords, *args, **options
  end

  def improper(a : Vec3,
               b : Vec3,
               c : Vec3,
               d : Vec3,
               lattice : Lattice? = nil) : Float64
    dihedral b, a, c, d, lattice
  end

  def squared_distance(a : Atom, b : Atom, lattice : Lattice? = nil) : Float64
    squared_distance a.coords, b.coords, lattice
  end

  @[AlwaysInline]
  def squared_distance(a : Vec3, b : Vec3, lattice : Lattice? = nil) : Float64
    b = b.wrap lattice, around: a if lattice
    (a.x - b.x)**2 + (a.y - b.y)**2 + (a.z - b.z)**2
  end
end
