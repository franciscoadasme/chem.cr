module Chem::Spatial
  struct Bounds
    getter origin : Vector
    getter size : Size3D

    def initialize
      initialize Vector.origin, Size3D.new(1, 1, 1)
    end

    def initialize(@origin : Vector, @size : Size3D)
    end

    def initialize(vmin : Vector, vmax : Vector)
      vd = vmax - vmin
      initialize vmin, Size3D.new(vd.x, vd.y, vd.z)
    end

    def center : Vector
      @origin + @size / 2
    end
  end
end
