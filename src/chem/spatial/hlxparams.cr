module Chem::Spatial
  struct HlxParams
    getter radius : Float64
    getter rotaxis : Vector
    getter theta : Float64
    getter zeta : Float64

    def initialize(@rotaxis : Vector,
                   @theta : Float64,
                   @zeta : Float64,
                   @radius : Float64)
    end
  end

  def hlxparams(res : Residue) : HlxParams?
    return nil unless res.protein?
    return nil unless prev_res = res.previous
    return nil unless next_res = res.next
    return nil unless res.bonded?(prev_res) && res.bonded?(next_res)

    coord = {
      {ca: prev_res["CA"].coords, c: prev_res["C"].coords},
      {n: res["N"].coords, ca: res["CA"].coords, c: res["C"].coords},
      {n: next_res["N"].coords, ca: next_res["CA"].coords},
    }

    tz, theta, zeta = rotation coord
    zeta *= chirality res, coord
    HlxParams.new tz, theta.degrees, zeta, radius(coord, theta)
  rescue KeyError
    nil
  end

  private def chirality(res, coord) : Int32
    chirality = 1
    if c_CB = res["CB"]?.try(&.coords)
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
      chirality = -1 if res.name != "GLY" && 0 < phi <= 125
    end
    chirality
  end

  private def radius(coord, theta : Float64) : Float64
    r1 = (coord[1][:ca] - coord[0][:ca])
    r1.magnitude / (2 * Math.sin(0.5 * theta))
  end

  private def rotation(coord) : Tuple(Vector, Float64, Float64)
    v1 = coord[0][:c] - coord[0][:ca]
    v2 = coord[1][:n] - coord[0][:ca]
    v3 = v1.cross(v2).normalize
    v1 = (v1 + v2).normalize

    w1 = coord[1][:c] - coord[1][:ca]
    w2 = coord[2][:n] - coord[1][:ca]
    w3 = w1.cross(w2).normalize
    w1 = (w1 + w2).normalize

    tz = (w1 - v1).cross(w3 - v3).normalize

    c1 = (coord[0][:ca] + coord[0][:c] + coord[1][:n] + coord[1][:ca]) / 4
    c2 = (coord[1][:ca] + coord[1][:c] + coord[2][:n] + coord[2][:ca]) / 4
    zeta = tz.dot(c2 - c1)
    tz, zeta = -tz, -zeta if zeta < 0

    {tz, rotation_angle(tz, v1, w1), zeta}
  end

  private def rotation_angle(rotaxis : Vector, v1 : Vector, w1 : Vector) : Float64
    v1p = (v1 - rotaxis * rotaxis.dot(v1)).normalize
    w1p = (w1 - rotaxis * rotaxis.dot(w1)).normalize
    theta = Math.acos v1p.dot(w1p)

    tzp = v1p.cross(w1p).normalize
    handedness = rotaxis.dot tzp
    handedness = 1 if handedness.abs < 1e-9
    handedness /= handedness.abs
    theta * handedness + Math::PI * (1 - handedness)
  end
end
