module Chem::Spatial
  struct Bounds
    getter basis : Basis
    getter origin : Vec3

    delegate a, alpha, angles, b, beta, c, gamma, i, j, k, size, to: @basis

    def initialize(@origin : Vec3, @basis : Basis)
    end

    def self.new(origin : Vec3, *args, **options) : self
      new origin, Basis.new(*args, **options)
    end

    def self.new(*args, **options) : self
      new Vec3.zero, Basis.new(*args, **options)
    end

    def self.new(vmin : Vec3, vmax : Vec3) : self
      new vmin,
        Vec3[vmax.x - vmin.x, 0, 0],
        Vec3[0, vmax.y - vmin.y, 0],
        Vec3[0, 0, vmax.z - vmin.z]
    end

    def self.[](a : Float64, b : Float64, c : Float64) : self
      new Vec3.zero, Size[a, b, c]
    end

    def self.zero : self
      new Vec3.zero, Size[0, 0, 0]
    end

    {% for op in %w(+ -) %}
      def {{op.id}}(rhs : Vec3) : self
        Bounds.new @origin {{op.id}} rhs, @basis
      end
    {% end %}

    # {% for op in %w(* /) %}
    #   def {{op.id}}(rhs : Number) : self
    #     Bounds.new @origin, @a {{op.id}} rhs, @b {{op.id}} rhs, @c {{op.id}} rhs
    #   end
    # {% end %}

    def center : Vec3
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
    # Vec3[0.0, 0.0, 0.0]
    # Vec3[0.0, 0.0, 20.0]
    # Vec3[0.0, 10.0, 0.0]
    # Vec3[0.0, 10.0, 20.0]
    # Vec3[5.0, 0.0, 0.0]
    # Vec3[5.0, 0.0, 20.0]
    # Vec3[5.0, 10.0, 0.0]
    # Vec3[5.0, 10.0, 20.0]
    # ```
    def each_vertex(& : Vec3 ->) : Nil
      2.times do |di|
        2.times do |dj|
          2.times do |dk|
            yield @origin + i * di + j * dj + k * dk
          end
        end
      end
    end

    # Returns `true` if the current instance contains *bounds*, `false`
    # otherwise.
    #
    # It effectively checks if every vertex of *bounds* is contained by
    # the current instance.
    #
    # ```
    # bounds = Bounds.new S[10, 10, 10], 90, 90, 120
    # bounds.includes? Bounds.new(Size[5, 4, 6])                     # => true
    # bounds.includes? Bounds.new(Vec3[-1, 2, -4], Size[5, 4, 6])) # => false
    # ```
    def includes?(bounds : Bounds) : Bool
      bounds.vertices.all? { |vec| includes?(vec) }
    end

    def includes?(vec : Vec3) : Bool
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
    # bounds = Bounds.new Vec3[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120
    # bounds.max # => Vec3[6.5, 11.66, 11.6]
    # ```
    def max : Vec3
      @origin + i + j + k
    end

    # Returns minimum edge. This is equivalent to the origin.
    #
    # ```
    # bounds = Bounds.new Vec3[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120
    # bounds.min # => Vec3[1.5, 3, -0.4]
    # ```
    def min : Vec3
      @origin
    end

    # Returns a bounds with its extents expanded by *padding* in every
    # direction. Note that its size is actually increased by `padding *
    # 2`.
    #
    # ```
    # bounds = Bounds.new Vec3[1, 5, 3], S[10, 5, 12]
    # bounds.center # => Vec3[6.0, 7.5, 9.0]
    # bounds = bounds.pad(2.5)
    # bounds.size   # => Size[15, 10, 17]
    # bounds.center # => Vec3[6.0, 7.5, 9.0]
    # ```
    def pad(padding : Number) : self
      raise ArgumentError.new "Padding cannot be negative" if padding < 0
      new_origin = @origin - i.resize(padding) - j.resize(padding) - k.resize(padding)
      Bounds.new new_origin, i.pad(padding * 2), j.pad(padding * 2), k.pad(padding * 2)
    end

    # Returns a bounds translated by *offset*.
    #
    # ```
    # bounds = Bounds.new Vec3[-5, 1, 20], S[10, 10, 10], 90, 90, 120
    # bounds.translate(Vec3[1, 2, 10]).min # => Vec3[-4.0, 3.0, 30.0]
    # ```
    def translate(offset : Vec3) : self
      Bounds.new @origin + offset, basis
    end

    # Returns bounds' vertices.
    #
    # ```
    # bounds = Bounds[5, 10, 20]
    # bounds.vertices # => [Vec3[0.0, 0.0, 0.0], Vec3[0.0, 0.0, 20.0], ...]
    # ```
    def vertices : Array(Vec3)
      vertices = [] of Vec3
      each_vertex { |vec| vertices << vec }
      vertices
    end

    def volume : Float64
      @basis.i.dot @basis.j.cross(@basis.k)
    end
  end
end
