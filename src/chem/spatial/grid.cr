module Chem::Spatial
  # TODO: add support for non-cubic grids (use lattice instead of bounds?)
  #       - i to coords: origin.x + (i / nx) * lattice.a
  #       - coords to i: ?
  # TODO: implement functionality from vmd's volmap
  class Grid
    alias Dimensions = Tuple(Int32, Int32, Int32)
    alias Index = Tuple(Int32, Int32, Int32)
    record Info, bounds : Bounds, dim : Dimensions

    getter bounds : Bounds
    getter dim : Dimensions

    @buffer : Pointer(Float64)

    delegate includes?, origin, volume, to: @bounds

    def initialize(@dim : Dimensions, @bounds : Bounds)
      check_dim
      @buffer = Pointer(Float64).malloc size
    end

    def initialize(@dim : Dimensions, @bounds : Bounds, initial_value : Float64)
      check_dim
      @buffer = Pointer(Float64).malloc size, initial_value
    end

    def self.[](nx : Int, ny : Int, nz : Int) : self
      new({nx.to_i, ny.to_i, nz.to_i}, Bounds.zero)
    end

    def self.atom_distance(structure : Structure,
                           dim : Dimensions,
                           bounds : Bounds? = nil) : self
      grid = new dim, (bounds || structure.coords.bounds)
      kdtree = KDTree.new structure
      grid.map_with_coords! do |_, vec|
        Math.sqrt kdtree.nearest_with_distance(vec)[1]
      end
    end

    # Returns a grid filled with the distances to the nearest atom. It will have the
    # same bounds and points as *other*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # info = Grid::Info.new Bounds[1.5, 2.135, 6.12], {10, 10, 10}
    # grid = Grid.atom_distance structure, info.dim, info.bounds
    # Grid.atom_distance_like(info, structure) == grid # => true
    # ```
    def self.atom_distance_like(other : self | Info, structure : Structure) : self
      atom_distance structure, other.dim, other.bounds
    end

    def self.build(dim : Dimensions,
                   bounds : Bounds,
                   &block : Pointer(Float64) ->)
      grid = new dim, bounds
      yield grid.to_unsafe
      grid
    end

    # Returns a zero-filled grid with the same bounds and points as *other*.
    #
    # ```
    # grid = Grid.from_dx "/path/to/grid"
    # other = Grid.empty_like grid
    # other.bounds == grid.bounds # => true
    # other.dim == grid.dim       # => true
    # other.to_a.minmax           # => {0.0, 0.0}
    # ```
    def self.empty_like(other : self | Info) : self
      new other.dim, other.bounds
    end

    # Returns a grid with the same bounds and points as *other* filled with *value*.
    #
    # ```
    # grid = Grid.from_dx "/path/to/grid"
    # other = Grid.fill_like grid, 2345.123
    # other.bounds == grid.bounds # => true
    # other.dim == grid.dim       # => true
    # other.to_a.minmax           # => {2345.123, 2345.123}
    # ```
    def self.fill_like(other : self | Info, value : Number) : self
      new other.dim, other.bounds, value.to_f
    end

    def self.info(path : Path | String) : Info
      info path, IO::FileFormat.from_filename File.basename(path)
    end

    def self.info(input : ::IO | Path | String, format : IO::FileFormat) : Info
      {% begin %}
        case format
        {% for parser in Parser.subclasses.select(&.annotation(IO::FileType)) %}
          when .{{parser.annotation(IO::FileType)[:format].id.underscore.id}}?
            {{parser}}.new(input).info
        {% end %}
        else
          raise ArgumentError.new "#{format} not supported for Grid"
        end
      {% end %}
    end

    def self.new(dim : Dimensions,
                 bounds : Bounds,
                 &block : Int32, Int32, Int32 -> Number)
      new(dim, bounds).map_with_index! do |_, i, j, k|
        (yield i, j, k).to_f
      end
    end

    # TODO: add more tests
    # FIXME: check delta calculation (grid.resolution.min / 2 shouldn't be enough?)
    def self.vdw_mask(structure : Structure,
                      dim : Dimensions,
                      bounds : Bounds? = nil,
                      delta : Float64 = 0.02) : self
      grid = new dim, (bounds || structure.coords.bounds)
      delta = Math.min delta, grid.resolution.min / 2
      kdtree = KDTree.new structure
      vdw_cutoff = structure.each_atom.max_of &.vdw_radius
      # grid.map_with_coords! do |_, vec|
      #   value = 0
      #   kdtree.each_neighbor(vec, within: vdw_cutoff) do |atom, d|
      #     next if value < 0
      #     d = Math.sqrt(d) - atom.vdw_radius
      #     if d < -delta
      #       value = -1
      #     elsif d < delta
      #       value = 1
      #     end
      #   end
      #   value.clamp(0, 1)
      # end
      structure.each_atom do |atom|
        grid.each_index(atom.coords, atom.vdw_radius + delta) do |i, j, k, d|
          too_close = false
          kdtree.each_neighbor(grid.coords_at(i, j, k), within: vdw_cutoff) do |other, od|
            too_close = true if Math.sqrt(od) < other.vdw_radius - delta
          end
          grid[i, j, k] = 1 if !too_close && (d - atom.vdw_radius).abs < delta
        end
      end
      grid
    end

    # Returns a grid mask with the points at the vdW spheres set to 1. It will have the
    # same bounds and points as *other*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # info = Grid::Info.new Bounds[5.213, 6.823, 10.352], {20, 25, 40}
    # grid = Grid.vdw_mask structure, info.dim, info.bounds
    # Grid.vdw_mask_like(info, structure) == grid # => true
    # ```
    def self.vdw_mask_like(other : self | Info,
                           structure : Structure,
                           delta : Float64 = 0.02) : self
      vdw_mask structure, other.dim, other.bounds, delta
    end

    def ==(rhs : self) : Bool
      return false unless @dim == rhs.dim && @bounds == rhs.bounds
      size.times do |i|
        return false if unsafe_fetch(i) != rhs.unsafe_fetch(i)
      end
      true
    end

    {% for op in %w(+ - * /) %}
      def {{op.id}}(rhs : Number) : self
        Grid.build(@dim, @bounds) do |buffer|
          size.times do |i|
            buffer[i] = unsafe_fetch(i) {{op.id}} rhs
          end
        end
      end

      def {{op.id}}(rhs : self) : self
        raise ArgumentError.new "Incompatible grid" unless @dim == rhs.dim
        Grid.build(@dim, @bounds) do |buffer|
          size.times do |i|
            buffer[i] = unsafe_fetch(i) {{op.id}} rhs.unsafe_fetch(i)
          end
        end
      end
    {% end %}

    @[AlwaysInline]
    def [](i : Int, j : Int, k : Int) : Float64
      self[i, j, k]? || raise IndexError.new
    end

    @[AlwaysInline]
    def [](vec : Vector) : Float64
      self[vec]? || raise IndexError.new
    end

    @[AlwaysInline]
    def []?(i : Int, j : Int, k : Int) : Float64?
      if i_ = internal_index?(i, j, k)
        unsafe_fetch i_
      else
        nil
      end
    end

    # TODO: add interpolation (check ARBInterp)
    @[AlwaysInline]
    def []?(vec : Vector) : Float64?
      if index = index(vec)
        unsafe_fetch index[0], index[1], index[2]
      end
    end

    @[AlwaysInline]
    def []=(i : Int, j : Int, k : Int, value : Float64) : Float64
      raise IndexError.new unless i_ = internal_index?(i, j, k)
      @buffer[i_] = value
    end

    def coords_at(i : Int, j : Int, k : Int) : Vector
      coords_at?(i, j, k) || raise IndexError.new
    end

    def coords_at?(i : Int, j : Int, k : Int) : Vector?
      return unless internal_index?(i, j, k)
      unsafe_coords_at i, j, k
    end

    def dup : self
      Grid.build(@dim, @bounds) do |buffer|
        buffer.copy_from @buffer, size
      end
    end

    def each(& : Float64 ->) : Nil
      size.times do |i_|
        yield unsafe_fetch(i_)
      end
    end

    def each_coords(& : Vector ->) : Nil
      each_index do |i, j, k|
        yield unsafe_coords_at(i, j, k)
      end
    end

    def each_index(& : Int32, Int32, Int32 ->) : Nil
      nx.times do |i|
        ny.times do |j|
          nz.times do |k|
            yield i, j, k
          end
        end
      end
    end

    def each_index(vec : Vector, cutoff : Number, & : Int32, Int32, Int32, Float64 ->) : Nil
      return unless index = index(vec)
      di, dj, dk = resolution.map { |ele| (cutoff / ele).to_i }
      cutoff *= cutoff
      ((index[0] - di - 1)..(index[0] + di + 1)).clamp(0..nx - 1).each do |i|
        ((index[1] - dj - 1)..(index[1] + dj + 1)).clamp(0..ny - 1).each do |j|
          ((index[2] - dk - 1)..(index[2] + dk + 1)).clamp(0..nz - 1).each do |k|
            d = Spatial.squared_distance vec, unsafe_coords_at(i, j, k)
            yield i, j, k, Math.sqrt(d) if d < cutoff
          end
        end
      end
    end

    def each_with_coords(& : Float64, Vector ->) : Nil
      each_index do |i, j, k|
        yield unsafe_fetch(i, j, k), unsafe_coords_at(i, j, k)
      end
    end

    def each_with_index(& : Float64, Int32, Int32, Int32 ->) : Nil
      each_index do |i, j, k|
        yield unsafe_fetch(i, j, k), i, j, k
      end
    end

    def index(vec : Vector) : Index?
      return unless bounds.includes? vec
      rx, ry, rz = resolution
      i = ((vec.x - origin.x) / rx).to_i
      j = ((vec.y - origin.y) / ry).to_i
      k = ((vec.z - origin.z) / rz).to_i
      {i, j, k}
    end

    def index!(vec : Vector) : Index
      index(vec) || raise IndexError.new
    end

    def map(& : Float64 -> Float64) : self
      dup.map! do |ele|
        yield ele
      end
    end

    def map!(& : Float64 -> Float64) : self
      @buffer.map!(size) { |ele| yield ele }
      self
    end

    def map_with_coords(& : Float64, Vector -> Number) : self
      dup.map_with_coords! do |ele, vec|
        yield ele, vec
      end
    end

    def map_with_coords!(& : Float64, Vector -> Number) : self
      size.times do |i_|
        i, j, k = raw_to_index i_
        @buffer[i_] = (yield @buffer[i_], unsafe_coords_at(i, j, k)).to_f
      end
      self
    end

    def map_with_index(& : Float64, Int32, Int32, Int32 -> Number) : self
      dup.map_with_index! do |ele, i, j, k|
        yield ele, i, j, k
      end
    end

    def map_with_index!(& : Float64, Int32, Int32, Int32 -> Number) : self
      size.times do |i_|
        i, j, k = raw_to_index i_
        @buffer[i_] = (yield @buffer[i_], i, j, k).to_f
      end
      self
    end

    {% for axis, i in %w(x y z) %}
      def n{{axis.id}} : Int32
        dim[{{i}}]
      end
    {% end %}

    def resolution : Tuple(Float64, Float64, Float64)
      {nx == 1 ? 0.0 : bounds.size.x / (nx - 1),
       ny == 1 ? 0.0 : bounds.size.y / (ny - 1),
       nz == 1 ? 0.0 : bounds.size.z / (nz - 1)}
    end

    def size : Int32
      nx * ny * nz
    end

    def step(n : Int) : self
      step n, n, n
    end

    def step(ni : Int, nj : Int, nk : Int) : self
      raise ArgumentError.new "Invalid step size" unless ni > 0 && nj > 0 && nk > 0
      new_nx = nx // ni
      new_nx += 1 if new_nx % ni > 0
      new_ny = ny // nj
      new_ny += 1 if new_ny % nj > 0
      new_nz = nz // nk
      new_nz += 1 if new_nz % nk > 0
      Grid.new({new_nx, new_ny, new_nz}, bounds) do |i, j, k|
        unsafe_fetch i * ni, j * nj, k * nk
      end
    end

    def to_a : Array(Float64)
      Array(Float64).build(size) do |buffer|
        buffer.copy_from @buffer, size
        size
      end
    end

    def to_unsafe : Pointer(Float64)
      @buffer
    end

    @[AlwaysInline]
    def unsafe_fetch(i : Int, j : Int, k : Int) : Float64
      to_unsafe[unsafe_index(i, j, k)]
    end

    private def check_dim : Nil
      raise ArgumentError.new "Invalid dimensions" unless dim.all?(&.>(0))
    end

    private def internal_index?(i : Int, j : Int, k : Int) : Int32?
      i += nx if i < 0
      j += ny if j < 0
      k += nz if k < 0
      if 0 <= i < nx && 0 <= j < ny && 0 <= k < nz
        unsafe_index i, j, k
      else
        nil
      end
    end

    @[AlwaysInline]
    private def raw_to_index(i_ : Int) : Index
      i = i_ // (ny * nz)
      j = (i_ // nz) % ny
      k = i_ % nz
      {i, j, k}
    end

    @[AlwaysInline]
    private def unsafe_coords_at(i : Int, j : Int, k : Int) : Vector
      rx, ry, rz = resolution
      Vector[origin.x + i * rx, origin.y + j * ry, origin.z + k * rz]
    end

    @[AlwaysInline]
    protected def unsafe_fetch(i : Int) : Float64
      @buffer[i]
    end

    @[AlwaysInline]
    private def unsafe_index(i : Int, j : Int, k : Int) : Int
      i * ny * nz + j * nz + k
    end
  end
end
