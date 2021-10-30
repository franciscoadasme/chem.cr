module Chem::Spatial
  struct Bounds
    getter basis : Mat3
    getter origin : Vec3

    # Caches the inverse matrix for coordinate conversion.
    @inv_basis : Spatial::Mat3?

    def initialize(@origin : Vec3, @basis : Mat3)
    end

    def self.new(vmin : Vec3, vmax : Vec3) : self
      basis = Mat3[
        {vmax.x - vmin.x, 0, 0},
        {0, vmax.y - vmin.y, 0},
        {0, 0, vmax.z - vmin.z},
      ]
      Bounds.new vmin, basis
    end

    def self.[](a : Float64, b : Float64, c : Float64) : self
      raise ArgumentError.new("Negative size") if {a, b, c}.any?(&.negative?)
      new Vec3.zero, Mat3.diagonal(a, b, c)
    end

    def basisvec : Tuple(Vec3, Vec3, Vec3)
      {Vec3[*@basis[.., 0]], Vec3[*@basis[.., 1]], Vec3[*@basis[.., 2]]}
    end

    def center : Vec3
      @origin + basisvec.sum * 0.5
    end

    def close_to?(rhs : self, delta : Number = Float64::EPSILON) : Bool
      @origin.close_to?(rhs.origin, delta) &&
        @basis.close_to?(rhs.basis, delta)
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
      vi, vj, vk = basisvec
      2.times do |di|
        2.times do |dj|
          2.times do |dk|
            yield @origin + vi * di + vj * dj + vk * dk
          end
        end
      end
    end

    # Returns the vector in fractional coordinates equivalent to the
    # given Cartesian coordinates.
    protected def fract(vec : Vec3) : Vec3
      inv_basis * vec
    end

    # Returns `true` if the current instance contains *bounds*, `false`
    # otherwise.
    #
    # It effectively checks if every vertex of *bounds* is contained by
    # the current instance.
    #
    # ```
    # bounds = Bounds.new S[10, 10, 10], 90, 90, 120
    # bounds.includes? Bounds.new(Size3[5, 4, 6])                     # => true
    # bounds.includes? Bounds.new(Vec3[-1, 2, -4], Size3[5, 4, 6])) # => false
    # ```
    def includes?(bounds : Bounds) : Bool
      bounds.each_vertex do |vec|
        return false unless vec.in?(self)
      end
      true
    end

    def includes?(vec : Vec3) : Bool
      vi, vj, vk = basisvec
      vec -= @origin unless @origin.zero?
      if vi.x? && vj.y? && vk.z?
        0 <= vec.x <= vi.x && 0 <= vec.y <= vj.y && 0 <= vec.z <= vk.z
      else
        vec = fract(vec).map &.round(Float64::DIGITS) # TODO: cache inverted
        0 <= vec.x <= 1 && 0 <= vec.y <= 1 && 0 <= vec.z <= 1
      end
    end

    # Inverted matrix basis.
    private def inv_basis : Spatial::Mat3
      @inv_basis ||= @basis.inv
    end

    # Returns maximum edge.
    #
    # ```
    # bounds = Bounds.new Vec3[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120
    # bounds.max # => Vec3[6.5, 11.66, 11.6]
    # ```
    def max : Vec3
      @origin + basisvec.sum
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
    # bounds.size   # => Size3[15, 10, 17]
    # bounds.center # => Vec3[6.0, 7.5, 9.0]
    # ```
    def pad(padding : Number) : self
      raise ArgumentError.new "Negative padding" if padding < 0
      vi, vj, vk = basisvec
      origin = @origin - (vi.resize(padding) + vj.resize(padding) + vk.resize(padding))
      padding *= 2
      basis = Spatial::Mat3.basis(vi.pad(padding), vj.pad(padding), vk.pad(padding))
      Bounds.new origin, basis
    end

    def size : Size3
      Size3[*basisvec.map(&.abs)]
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
      @basis.det
    end
  end
end
