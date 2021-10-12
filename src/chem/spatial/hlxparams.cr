module Chem::Spatial
  record HlxParams,
    rotaxis : Vec3,
    twist : Float64,
    pitch : Float64,
    radius : Float64 do
    def to_q : Quaternion
      Quaternion.rotation about: @rotaxis, by: @twist
    end
  end

  def hlxparams(res : Residue, lattice : Lattice? = nil) : HlxParams?
    return unless res.protein? && (prev_res = res.pred) && (next_res = res.succ)

    coord =
      if lattice
        ca2 = res["CA"].coords
        n2 = res["N"].coords.wrap lattice, around: ca2
        c2 = res["C"].coords.wrap lattice, around: ca2
        cb2 = res["CB"]?.try &.coords.wrap(lattice, around: ca2)
        c1 = prev_res["C"].coords.wrap lattice, around: n2
        ca1 = prev_res["CA"].coords.wrap lattice, around: c1
        n3 = next_res["N"].coords.wrap lattice, around: c2
        ca3 = next_res["CA"].coords.wrap lattice, around: n2
        { {ca: ca1, c: c1}, {n: n2, ca: ca2, c: c2, cb: cb2}, {n: n3, ca: ca3} }
      else
        {
          {ca: prev_res["CA"].coords, c: prev_res["C"].coords},
          {n:  res["N"].coords,
           ca: res["CA"].coords,
           c:  res["C"].coords,
           cb: res["CB"]?.try(&.coords)},
          {n: next_res["N"].coords, ca: next_res["CA"].coords},
        }
      end

    rotaxis, twist, pitch = rotation coord
    chirality = chirality coord
    pitch, rotaxis, twist = -pitch, -rotaxis, 2 * Math::PI - twist if chirality < 0
    HlxParams.new rotaxis, twist.degrees, pitch, radius(coord, twist)
  rescue KeyError
    nil
  end

  private def chirality(coord) : Int32
    chirality = 1
    if c_CB = coord[1][:cb]
      d1 = coord[1][:n] - coord[1][:ca]
      d2 = c_CB - coord[1][:ca]
      d3 = coord[1][:c] - coord[1][:ca]
      d4 = coord[0][:c] - coord[1][:n]

      v2 = d1.cross(d3).normalize
      v1 = v2.cross(d1).normalize
      v3 = (d2.dot(v1) * v1 + d2.dot(v2) * v2).normalize
      v4 = (d4.dot(v1) * v1 + d4.dot(v2) * v2).normalize
      v5 = v1.cross(v4)

      chirality = -1 if d1.dot(v5) > 0 && angle(v1, v4) <= angle(v1, v3)
    else
      phi = dihedral coord[0][:c], coord[1][:n], coord[1][:ca], coord[1][:c]
      chirality = -1 if phi > 0
      # chirality = -1 if res.name != "GLY" && 0 < phi <= 125
    end
    chirality
  end

  private def radius(coord, theta : Float64) : Float64
    r1 = (coord[1][:ca] - coord[0][:ca])
    r1.size / (2 * Math.sin(0.5 * theta))
  end

  private def rotation(coord) : Tuple(Vec3, Float64, Float64)
    v1 = coord[0][:c] - coord[0][:ca]
    v2 = coord[1][:n] - coord[0][:c]
    v3 = v1.cross(v2).normalize
    v1 = v1.normalize

    w1 = coord[1][:c] - coord[1][:ca]
    w2 = coord[2][:n] - coord[1][:c]
    w3 = w1.cross(w2).normalize
    w1 = w1.normalize

    rotaxis = (w1 - v1).cross(w3 - v3).normalize
    rotaxis *= rotaxis.dot(v1).sign # ensures that rotation axis points forwards

    c1 = (coord[0][:ca] + coord[0][:c] + coord[1][:n] + coord[1][:ca]) / 4
    c2 = (coord[1][:ca] + coord[1][:c] + coord[2][:n] + coord[2][:ca]) / 4
    translation = rotaxis.dot(c2 - c1)

    {rotaxis, rotation_angle(rotaxis, v1, w1), translation}
  end

  private def rotation_angle(rotaxis : Vec3, v1 : Vec3, w1 : Vec3) : Float64
    v1p = (v1 - rotaxis * rotaxis.dot(v1)).normalize
    w1p = (w1 - rotaxis * rotaxis.dot(w1)).normalize
    twist = Math.acos v1p.dot(w1p)

    tzp = v1p.cross(w1p).normalize
    handedness = rotaxis.dot tzp
    handedness = 1.0 if handedness.abs < 1e-9
    handedness /= handedness.abs
    twist * handedness + Math::PI * (1 - handedness)
  end
end
