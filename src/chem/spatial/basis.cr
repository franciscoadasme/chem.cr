module Chem::Spatial
  struct Basis
    getter i : Vec3
    getter j : Vec3
    getter k : Vec3

    def initialize(@i : Vec3, @j : Vec3, @k : Vec3)
    end

    def self.new(size : Size3,
                 alpha : Number = 90.0,
                 beta : Number = 90.0,
                 gamma : Number = 90.0) : self
      raise ArgumentError.new("Negative angle") if alpha < 0 || beta < 0 || gamma < 0
      if alpha == 90 && beta == 90 && gamma == 90
        i = Vec3[size[0], 0, 0]
        j = Vec3[0, size[1], 0]
        k = Vec3[0, 0, size[2]]
      else
        cos_alpha = Math.cos alpha.radians
        cos_beta = Math.cos beta.radians
        cos_gamma = Math.cos gamma.radians
        sin_gamma = Math.sin gamma.radians

        kx = size[2] * cos_beta
        ky = size[2] * (cos_alpha - cos_beta * cos_gamma) / sin_gamma
        kz = Math.sqrt size[2]**2 - kx**2 - ky**2

        i = Vec3[size[0], 0, 0]
        j = Vec3[size[1] * cos_gamma, size[1] * sin_gamma, 0]
        k = Vec3[kx, ky, kz]
      end
      new i, j, k
    end

    def ==(rhs : self) : Bool
      @i == rhs.i && @j == rhs.j && @k == rhs.k
    end

    def a : Float64
      @i.abs
    end

    def alpha : Float64
      Spatial.angle @j, @k
    end

    def angles : Tuple(Float64, Float64, Float64)
      {alpha, beta, gamma}
    end

    def b : Float64
      @j.abs
    end

    def beta : Float64
      Spatial.angle @i, @k
    end

    def c : Float64
      @k.abs
    end

    def gamma : Float64
      Spatial.angle @i, @j
    end

    def size : Size3
      Size3.new @i.abs, @j.abs, @k.abs
    end

    # Returns the transformation that converts Cartesian coordinates to fractional
    # coordinates in terms of the basis vectors.
    #
    # This is equivalent to the basis change from standard to the basis defined by the
    # lattice vectors, which is calculated as the inverse of the latter
    def transform : AffineTransform
      @basis_transform ||= AffineTransform.build do |buffer|
        det = @i.x * (@j.y * @k.z - @j.z * @k.y) -
              @j.x * (@i.y * @k.z + @k.y * @i.z) +
              @k.x * (@i.y * @j.z - @j.y * @i.z)
        inv_det = 1 / det
        buffer[0] = (@j.y * @k.z - @j.z * @k.y) * inv_det
        buffer[1] = (@k.x * @j.z - @j.x * @k.z) * inv_det
        buffer[2] = (@j.x * @k.y - @k.x * @j.y) * inv_det
        buffer[4] = (@k.y * @i.z - @i.y * @k.z) * inv_det
        buffer[5] = (@i.x * @k.z - @k.x * @i.z) * inv_det
        buffer[6] = (@i.y * @k.x - @i.x * @k.y) * inv_det
        buffer[8] = (@i.y * @j.z - @i.z * @j.y) * inv_det
        buffer[9] = (@i.z * @j.x - @i.x * @j.z) * inv_det
        buffer[10] = (@i.x * @j.y - @i.y * @j.x) * inv_det
      end
    end
  end
end
