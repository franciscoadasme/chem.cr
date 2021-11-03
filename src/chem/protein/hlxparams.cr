module Chem::Protein
  struct HlxParams
    getter rotaxis : Spatial::Vec3
    getter twist : Float64
    getter pitch : Float64
    getter radius : Float64

    def initialize(residue : Residue)
      raise ArgumentError.new("#{residue} is not protein") unless residue.protein?
      raise ArgumentError.new("#{residue} is N-terminus") unless prev_res = residue.pred
      raise ArgumentError.new("#{residue} is C-terminus") unless next_res = residue.succ

      c1 = prev_res.dig("C").coords
      ca1 = prev_res.dig("CA").coords
      n2 = residue.dig("N").coords
      ca2 = residue.dig("CA").coords
      c2 = residue.dig("C").coords
      cb2 = residue.dig?("CB").try &.coords
      n3 = next_res.dig("N").coords
      ca3 = next_res.dig("CA").coords

      if cell = residue.structure.cell
        n2 = n2.wrap cell, around: ca2
        c2 = c2.wrap cell, around: ca2
        cb2 = cb2.try &.wrap(cell, around: ca2)
        c1 = c1.wrap cell, around: n2
        ca1 = ca1.wrap cell, around: c1
        n3 = n3.wrap cell, around: c2
        ca3 = ca3.wrap cell, around: n3
      end

      # compute helix rotation axis using auxiliary vectors
      v1 = c1 - ca1
      v2 = n2 - c1
      v3 = v1.cross(v2).normalize
      v1 = v1.normalize

      w1 = c2 - ca2
      w2 = n3 - c2
      w3 = w1.cross(w2).normalize
      w1 = w1.normalize

      @rotaxis = (w1 - v1).cross(w3 - v3).normalize
      @rotaxis *= @rotaxis.dot(v1).sign # ensures that rotation axis points forwards

      # compute helix pitch
      c1 = (ca1 + c1 + n2 + ca2) / 4
      c2 = (ca2 + c2 + n3 + ca3) / 4
      @pitch = @rotaxis.dot(c2 - c1)

      # compute helix twist
      v1p = (v1 - @rotaxis * @rotaxis.dot(v1)).normalize
      w1p = (w1 - @rotaxis * @rotaxis.dot(w1)).normalize
      # round to avoid precision issues (e.g., -1.0000000000000002 would produce NaN)
      @twist = Math.acos v1p.dot(w1p).round(Float64::DIGITS)

      tzp = v1p.cross(w1p).normalize
      handedness = @rotaxis.dot tzp
      handedness = 1.0 if handedness.abs < 1e-9
      handedness /= handedness.abs
      @twist = @twist * handedness + Math::PI * (1 - handedness)

      # compute helix radius
      @radius = (ca2 - ca1).abs / (2 * Math.sin(0.5 * @twist))

      # compute chirality
      chirality = 1
      if c_CB = cb2
        d1 = n2 - ca2
        d2 = c_CB - ca2
        d3 = c2 - ca2
        d4 = c1 - n2

        v2 = d1.cross(d3).normalize
        v1 = v2.cross(d1).normalize
        v3 = (d2.dot(v1) * v1 + d2.dot(v2) * v2).normalize
        v4 = (d4.dot(v1) * v1 + d4.dot(v2) * v2).normalize
        v5 = v1.cross(v4)

        chirality = -1 if d1.dot(v5) > 0 && Spatial.angle(v1, v4) <= Spatial.angle(v1, v3)
      else
        phi = Spatial.dihedral c1, n2, ca2, c2
        chirality = -1 if phi > 0
        # chirality = -1 if res.name != "GLY" && 0 < phi <= 125
      end

      if chirality < 0
        @rotaxis *= -1
        @pitch *= -1
        @twist = 2 * Math::PI - @twist
      end
    end

    def to_q : Quat
      Quat.rotation about: @rotaxis, by: @twist.degrees
    end
  end
end
