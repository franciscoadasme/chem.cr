module Chem::Spatial
  struct Bounds
    getter basis : Basis
    getter origin : Vector

    delegate a, alpha, angles, b, beta, c, gamma, i, j, k, size, to: @basis

    def initialize(@origin : Vector, @basis : Basis)
    end

    def self.new(origin : Vector, *args, **options) : self
      new origin, Basis.new(*args, **options)
    end

    def self.new(*args, **options) : self
      new Vector.origin, Basis.new(*args, **options)
    end

    def self.new(vmin : Vector, vmax : Vector) : self
      new vmin,
        Vector[vmax.x - vmin.x, 0, 0],
        Vector[0, vmax.y - vmin.y, 0],
        Vector[0, 0, vmax.z - vmin.z]
    end

    def self.[](a : Float64, b : Float64, c : Float64) : self
      new Vector.origin, Size[a, b, c]
    end

    def self.zero : self
      new Vector.origin, Size[0, 0, 0]
    end

    {% for op in %w(+ -) %}
      def {{op.id}}(rhs : Vector) : self
        Bounds.new @origin {{op.id}} rhs, @basis
      end
    {% end %}

    # {% for op in %w(* /) %}
    #   def {{op.id}}(rhs : Number) : self
    #     Bounds.new @origin, @a {{op.id}} rhs, @b {{op.id}} rhs, @c {{op.id}} rhs
    #   end
    # {% end %}

    def center : Vector
      @origin + (@basis.i + @basis.j + @basis.k) * 0.5
    end

    # Yields bounds' vertices.
    #
    # ```
    # Bounds[5, 10, 20].each_vertex { |vec| puts vec }
    # ```
    #
    # Prints:
    #
    # ```text
    # Vector[0.0, 0.0, 0.0]
    # Vector[0.0, 0.0, 20.0]
    # Vector[0.0, 10.0, 0.0]
    # Vector[0.0, 10.0, 20.0]
    # Vector[5.0, 0.0, 0.0]
    # Vector[5.0, 0.0, 20.0]
    # Vector[5.0, 10.0, 0.0]
    # Vector[5.0, 10.0, 20.0]
    # ```
    def each_vertex(& : Vector ->) : Nil
      2.times do |di|
        2.times do |dj|
          2.times do |dk|
            yield @origin + i * di + j * dj + k * dk
          end
        end
      end
    end

    def includes?(vec : Vector) : Bool
      vec -= @origin unless @origin.zero?
      if alpha == 90 && beta == 90 && gamma == 90 && i.y == 0 && i.z == 0
        0 <= vec.x <= a && 0 <= vec.y <= b && 0 <= vec.z <= c
      else
        vec = vec.to_fractional(@basis).map &.round(Float64::DIGITS)
        0 <= vec.x <= 1 && 0 <= vec.y <= 1 && 0 <= vec.z <= 1
      end
    end

    # Returns maximum edge.
    #
    # ```
    # bounds = Bounds.new V[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120
    # bounds.max # => Vector[6.5, 11.66, 11.6]
    # ```
    def max : Vector
      @origin + i + j + k
    end

    # Returns minimum edge. This is equivalent to the origin.
    #
    # ```
    # bounds = Bounds.new V[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120
    # bounds.min # => Vector[1.5, 3, -0.4]
    # ```
    def min : Vector
      @origin
    end

    # Returns a bounds with its extents expanded by *padding* in every
    # direction. Note that its size is actually increased by `padding *
    # 2`.
    #
    # ```
    # bounds = Bounds.new Vector[1, 5, 3], S[10, 5, 12]
    # bounds.center # => Vector[6.0, 7.5, 9.0]
    # bounds = bounds.pad(2.5)
    # bounds.size   # => Size[15, 10, 17]
    # bounds.center # => Vector[6.0, 7.5, 9.0]
    # ```
    def pad(padding : Number) : self
      raise ArgumentError.new "Padding cannot be negative" if padding < 0
      new_origin = @origin - i.resize(padding) - j.resize(padding) - k.resize(padding)
      Bounds.new new_origin, i.pad(padding * 2), j.pad(padding * 2), k.pad(padding * 2)
    end

    # Returns a bounds translated by *offset*.
    #
    # ```
    # bounds = Bounds.new V[-5, 1, 20], S[10, 10, 10], 90, 90, 120
    # bounds.translate(V[1, 2, 10]).min # => Vector[-4.0, 3.0, 30.0]
    # ```
    def translate(offset : Vector) : self
      Bounds.new @origin + offset, basis
    end

    # Returns bounds' vertices.
    #
    # ```
    # bounds = Bounds[5, 10, 20]
    # bounds.vertices # => [Vector[0.0, 0.0, 0.0], Vector[0.0, 0.0, 20.0], ...]
    # ```
    def vertices : Array(Vector)
      vertices = [] of Vector
      each_vertex { |vec| vertices << vec }
      vertices
    end

    def volume : Float64
      @basis.i.dot @basis.j.cross(@basis.k)
    end
  end
end
