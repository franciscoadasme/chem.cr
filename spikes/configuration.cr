abstract struct Dispersion
end

struct GrimmeD3 < Dispersion
  enum Damping
    Zero
    BeckeJonson
  end

  @damping : Damping = :becke_jonson
  @a1 : Float64 = 1
  @a2 : Float64 = 1
  @s8 : Float64 = 1
  @sr6 : Float64 = 1
end
