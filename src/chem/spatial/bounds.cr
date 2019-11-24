module Chem::Spatial
  struct Bounds
    getter origin : Vector
    getter size : Size

    def initialize(@origin : Vector, @size : Size)
    end

    def self.[](x : Float64, y : Float64, z : Float64) : self
      new Vector.origin, Size.new(x, y, z)
    end

    def self.new(vmin : Vector, vmax : Vector) : self
      new vmin, Size.new(vmax.x - vmin.x, vmax.y - vmin.y, vmax.z - vmin.z)
    end

    def self.zero : self
      new Vector.origin, Size.zero
    end

    {% for op in %w(+ -) %}
      def {{op.id}}(rhs : Vector) : self
        Bounds.new @origin {{op.id}} rhs, @size
      end
    {% end %}

    {% for op in %w(* /) %}
      def {{op.id}}(rhs : Number) : self
        Bounds.new @origin, @size {{op.id}} rhs
      end
    {% end %}

    def center : Vector
      @origin + @size / 2
    end

    def includes?(vec : Vector) : Bool
      origin.x <= vec.x <= origin.x + size.x &&
        origin.y <= vec.y <= origin.y + size.y &&
        origin.z <= vec.z <= origin.z + size.z
    end
  end
end
