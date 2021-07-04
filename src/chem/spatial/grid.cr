module Chem::Spatial
  # TODO: add support for non-cubic grids (use lattice instead of bounds?)
  #       - i to coords: origin.x + (i / nx) * lattice.a
  #       - coords to i: ?
  # TODO: implement functionality from vmd's volmap
  class Grid
    include Indexable(Float64)

    alias Dimensions = Tuple(Int32, Int32, Int32)
    alias Location = Tuple(Int32, Int32, Int32)
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

    def self.[](ni : Int, nj : Int, nk : Int) : self
      new({ni.to_i, nj.to_i, nk.to_i}, Bounds.zero)
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

    # Creates a new `Grid` with *info* and yields a buffer to be filled.
    #
    # This method is **unsafe**, but it is usually used to initialize the buffer in a
    # linear fashion, e.g., reading values from a file.
    #
    # ```
    # Grid.build(Grid.info("/path/to/file")) do |buffer, size|
    #   size.times do |i|
    #     buffer[i] = read_value
    #   end
    # end
    # ```
    def self.build(info : Info, & : Pointer(Float64), Int32 ->) : self
      grid = empty_like info
      yield grid.to_unsafe, grid.size
      grid
    end

    def self.build(dim : Dimensions,
                   bounds : Bounds,
                   &block : Pointer(Float64), Int32 ->) : self
      grid = new dim, bounds
      yield grid.to_unsafe, grid.size
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
      info path, IO::Format.from_filename File.basename(path)
    end

    def self.info(input : ::IO | Path | String, format : IO::Format) : Info
      {% begin %}
        case format
        {% for parser in Reader.subclasses.select(&.annotation(IO::RegisterFormat)) %}
          when .{{parser.annotation(IO::RegisterFormat)[:format].id.underscore.id}}?
            {{parser}}.new(input).info
        {% end %}
        else
          raise ArgumentError.new "#{format} not supported for Grid"
        end
      {% end %}
    end

    def self.new(dim : Dimensions,
                 bounds : Bounds,
                 &block : Location -> Number)
      new(dim, bounds).map_with_loc! do |_, loc|
        (yield loc).to_f
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
        grid.each_loc(atom.coords, atom.vdw_radius + delta) do |loc, d|
          too_close = false
          kdtree.each_neighbor(grid.coords_at(loc), within: vdw_cutoff) do |other, od|
            too_close = true if Math.sqrt(od) < other.vdw_radius - delta
          end
          grid[loc] = 1 if !too_close && (d - atom.vdw_radius).abs < delta
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
      each_with_index do |ele, i|
        return false if ele != rhs.unsafe_fetch(i)
      end
      true
    end

    {% for op in %w(+ - * /) %}
      def {{op.id}}(rhs : Number) : self
        Grid.build(@dim, @bounds) do |buffer|
          each_with_index do |ele, i|
            buffer[i] = ele {{op.id}} rhs
          end
        end
      end

      def {{op.id}}(rhs : self) : self
        raise ArgumentError.new "Incompatible grid" unless @dim == rhs.dim
        Grid.build(@dim, @bounds) do |buffer|
          each_with_index do |ele, i|
            buffer[i] = ele {{op.id}} rhs.unsafe_fetch(i)
          end
        end
      end
    {% end %}

    @[AlwaysInline]
    def [](*args, **options) : Float64
      self[*args, **options]? || raise IndexError.new
    end

    @[AlwaysInline]
    def []?(i : Int, j : Int, k : Int) : Float64?
      self[Location.new(i, j, k)]?
    end

    @[AlwaysInline]
    def []?(loc : Location) : Float64?
      if i = index(loc)
        unsafe_fetch i
      end
    end

    # TODO: add interpolation (check ARBInterp)
    @[AlwaysInline]
    def []?(vec : Vector) : Float64?
      if i = index(vec)
        unsafe_fetch i
      end
    end

    @[AlwaysInline]
    def []=(i : Int, value : Float64) : Float64
      i += size if i < 0
      raise IndexError.new unless 0 <= i < size
      @buffer[i] = value
    end

    @[AlwaysInline]
    def []=(i : Int, j : Int, k : Int, value : Float64) : Float64
      self[Location.new(i, j, k)] = value
    end

    @[AlwaysInline]
    def []=(loc : Location, value : Float64) : Float64
      raise IndexError.new unless i = index(loc)
      @buffer[i] = value
    end

    def coords_at(*args, **options) : Vector
      coords_at?(*args, **options) || raise IndexError.new
    end

    def coords_at?(i : Int) : Vector?
      if loc = loc_at?(i)
        coords_at? loc
      end
    end

    def coords_at?(i : Int, j : Int, k : Int) : Vector?
      coords_at?(Location.new(i, j, k))
    end

    def coords_at?(loc : Location) : Vector?
      return unless index(loc)
      unsafe_coords_at(loc)
    end

    def dup : self
      Grid.build(@dim, @bounds) do |buffer|
        buffer.copy_from @buffer, size
      end
    end

    # Iterates over slices along *axis*. Axis is specified as an
    # integer: 0-2 refer to the direction of the first, second or third
    # basis vector, respectively.
    #
    # ```
    # grid = Grid.new({2, 3, 2}, Bounds[1, 1, 1]) { |i, j, k| i * 6 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
    # slices = [] of Array(Float64)
    # grid.each_axial_slice(axis: 1) { |slice| slices << slice }
    # slices # => [[0, 1, 6, 7], [2, 3, 8, 9], [4, 5, 10, 11]]
    # ```
    #
    # When using read-only slices, one can specify the *reuse* option to
    # prevent many memory allocations:
    #
    # * If *reuse* is an `Array`, this array will be reused.
    # * If *reuse* is true, the method will create a new array and reuse
    #   it.
    # * If *reuse* is false (default), a new array is created and
    #   yielded on each iteration.
    def each_axial_slice(axis : Int,
                         reuse : Bool | Array(Float64) = false,
                         & : Array(Float64) ->) : Nil
      njk = nj * nk
      case axis
      when 0
        each_axial_slice(ni, njk, reuse) do |buffer, i|
          njk.times { |i_| buffer << unsafe_fetch(i * njk + i_) }
          yield buffer
        end
      when 1
        each_axial_slice(nj, ni * nk, reuse) do |buffer, j|
          ni.times do |i|
            nk.times { |i_| buffer << unsafe_fetch(i * njk + j * nk + i_) }
          end
          yield buffer
        end
      when 2
        each_axial_slice(nk, ni * nj, reuse) do |buffer, k|
          ni.times do |i|
            nj.times do |j|
              buffer << unsafe_fetch(i * njk + j * nk + k)
            end
          end
          yield buffer
        end
      else
        raise IndexError.new
      end
    end

    def each_coords(& : Vector ->) : Nil
      each_loc do |loc|
        yield unsafe_coords_at(loc)
      end
    end

    def each_loc(& : Location ->) : Nil
      ni.times do |i|
        nj.times do |j|
          nk.times do |k|
            yield Location.new(i, j, k)
          end
        end
      end
    end

    def each_loc(vec : Vector, cutoff : Number, & : Location, Float64 ->) : Nil
      return unless loc = loc_at?(vec)
      di, dj, dk = resolution.map { |ele| (cutoff / ele).to_i }
      cutoff *= cutoff
      ((loc[0] - di - 1)..(loc[0] + di + 1)).clamp(0..ni - 1).each do |i|
        ((loc[1] - dj - 1)..(loc[1] + dj + 1)).clamp(0..nj - 1).each do |j|
          ((loc[2] - dk - 1)..(loc[2] + dk + 1)).clamp(0..nk - 1).each do |k|
            new_loc = Location.new i, j, k
            d = Spatial.squared_distance vec, unsafe_coords_at(new_loc)
            yield new_loc, Math.sqrt(d) if d < cutoff
          end
        end
      end
    end

    def each_with_coords(& : Float64, Vector ->) : Nil
      each_index do |i|
        yield unsafe_fetch(i), unsafe_coords_at(unsafe_loc_at(i))
      end
    end

    def each_with_loc(& : Float64, Location ->) : Nil
      each_with_index do |ele, i|
        yield ele, unsafe_loc_at(i)
      end
    end

    def index(loc : Location) : Int32?
      loc = loc.map_with_index { |ele, i| ele < 0 ? ele + @dim[i] : ele }
      loc.each_with_index do |ele, i|
        return unless 0 <= ele < @dim[i]
      end
      unsafe_index loc
    end

    def index(vec : Vector) : Int32?
      if loc = loc_at?(vec)
        unsafe_index loc
      end
    end

    def index!(*args, **options) : Int32
      index(*args, **options) || raise IndexError.new
    end

    def loc_at(*args, **options) : Location
      loc_at?(*args, **options) || raise IndexError.new
    end

    def loc_at?(i : Int) : Location?
      i += size if i < 0
      unsafe_loc_at(i) if 0 <= i < size
    end

    def loc_at?(vec : Vector) : Location?
      return unless vec.in?(bounds)
      vec = (vec - origin).to_fractional bounds.basis
      (vec * @dim.map &.-(1)).round.to_t.map &.to_i
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
      each_with_index do |ele, i|
        @buffer[i] = (yield ele, unsafe_coords_at(unsafe_loc_at(i))).to_f
      end
      self
    end

    def map_with_index(& : Float64, Int32 -> Number) : self
      dup.map_with_index! do |ele, i|
        yield ele, i
      end
    end

    def map_with_index!(& : Float64, Int32 -> Number) : self
      each_with_index do |ele, i|
        @buffer[i] = (yield ele, i).to_f
      end
      self
    end

    def map_with_loc(& : Float64, Location -> Number) : self
      dup.map_with_loc! do |ele, loc|
        yield ele, loc
      end
    end

    def map_with_loc!(& : Float64, Location -> Number) : self
      each_with_index do |ele, i|
        @buffer[i] = (yield ele, unsafe_loc_at(i)).to_f
      end
      self
    end

    # Returns a grid mask. Elements for which the passed block returns `true` are set to
    # 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i + j + k }
    # grid.to_a              # => [0, 1, 1, 2, 1, 2, 2, 3]
    # grid.mask(&.>(1)).to_a # => [0, 0, 0, 1, 0, 1, 1, 1]
    # grid.to_a              # => [0, 1, 1, 2, 1, 2, 2, 3]
    # ```
    def mask(& : Float64 -> Bool) : self
      map { |ele| (yield ele) ? 1.0 : 0.0 }
    end

    # Returns a grid mask. Elements for which `pattern === element` returns `true` are
    # set to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
    # grid.to_a              # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # grid.mask(2..4.5).to_a # => [0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0]
    # grid.to_a              # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # ```
    def mask(pattern) : self
      mask { |ele| pattern === ele }
    end

    # Returns a grid mask. Elements for which `(value - ele).abs <= delta` returns
    # `true` are set to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) / 5 }
    # grid.to_a              # => [0.2, 0.4, 0.6, 0.4, 0.8, 1.2, 0.4, 0.8, 1.2, 0.8, 1.6, 2.4]
    # grid.mask(1, 0.5).to_a # => [0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0]
    # grid.to_a              # => [0.2, 0.4, 0.6, 0.4, 0.8, 1.2, 0.4, 0.8, 1.2, 0.8, 1.6, 2.4]
    # ```
    def mask(value : Number, delta : Number) : self
      mask (value - delta)..(value + delta)
    end

    # Masks a grid by the passed block. Elements for which the passed block returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid * grid.mask
    # { ... }`.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i + j + k }
    # grid.to_a # => [0, 1, 1, 2, 1, 2, 2, 3]
    # grid.mask! &.>(1)
    # grid.to_a # => [0, 0, 0, 2, 0, 2, 2, 3]
    # ```
    def mask!(& : Float64 -> Bool) : self
      map! { |ele| (yield ele) ? ele : 0.0 }
    end

    # Masks a grid by *pattern*. Elements for which `pattern === element` returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask(pattern)`
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
    # grid.to_a # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # grid.mask! 2..4.5
    # grid.to_a # => [0, 2, 3, 2, 4, 0, 2, 4, 0, 4, 0, 0]
    # ```
    def mask!(pattern) : self
      mask! { |ele| pattern === ele }
    end

    # Masks a grid by *value*+/-*delta*. Elements for which `(value - ele).abs > delta`
    # returns `true` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid * grid.mask(value,
    # delta)`
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + j + k) / 5 }
    # grid.to_a # => [0.0, 0.2, 0.4, 0.2, 0.4, 0.6, 0.2, 0.4, 0.6, 0.4, 0.6, 0.8]
    # grid.mask! 0.5, 0.1
    # grid.to_a # => [0.0, 0.0, 0.4, 0.0, 0.4, 0.6, 0.0, 0.4, 0.6, 0.4, 0.6, 0.0]
    # ```
    def mask!(value : Number, delta : Number) : self
      mask! (value - delta)..(value + delta)
    end

    # Returns a grid mask. Coordinates for which the passed block returns `true` are set
    # to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a                           # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_coords(&.x.==(0)).to_a # => [1, 1, 1, 1, 0, 0, 0, 0]
    # grid.to_a                           # => [0, 1, 2, 3, 4, 5, 6, 7]
    # ```
    def mask_by_coords(& : Vector -> Bool) : self
      map_with_coords { |_, vec| (yield vec) ? 1.0 : 0.0 }
    end

    # Masks a grid by coordinates. Coordinates for which the passed block returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask_by_coords { ... }`
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[5, 5, 5]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_coords! { |vec| vec.y == 5 }
    # grid.to_a # => [0, 0, 2, 3, 0, 0, 6, 7]
    # ```
    def mask_by_coords!(& : Vector -> Bool) : self
      map_with_coords! { |ele, vec| (yield vec) ? ele : 0.0 }
    end

    # Returns a grid mask. Indexes for which the passed block returns `true` are set to
    # 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a                       # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_index(&.>(4)).to_a # => [0, 0, 0, 0, 0, 1, 1, 1]
    # grid.to_a                       # => [0, 1, 2, 3, 4, 5, 6, 7]
    # ```
    def mask_by_index(& : Int32 -> Bool) : self
      map_with_index { |_, i| (yield i) ? 1.0 : 0.0 }
    end

    # Masks a grid by index. Indexes for which the passed block returns `false` are set
    # to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask_by_index { ... }`
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[1, 1, 1]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_index! &.<(3)
    # grid.to_a # => [0, 1, 2, 0, 0, 0, 0, 0]
    # ```
    def mask_by_index!(& : Int32 -> Bool) : self
      map_with_index! { |ele, i| (yield i) ? ele : 0.0 }
    end

    # Returns a grid mask. Locations for which the passed block returns `true` are set
    # to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a                                  # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_loc { |i, j, k| k == 1 }.to_a # => [0, 1, 0, 1, 0, 1, 0, 1]
    # grid.to_a                                  # => [0, 1, 2, 3, 4, 5, 6, 7]
    # ```
    def mask_by_loc(& : Location -> Bool) : self
      map_with_loc { |_, loc| (yield loc) ? 1.0 : 0.0 }
    end

    # Masks a grid by location. Locations for which the passed block returns `false` are
    # set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid * grid.mask_by_loc
    # { ... }`
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[1, 1, 1]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_loc! { |(i, j, k)| i == 1 }
    # grid.to_a # => [0, 0, 0, 0, 4, 5, 6, 7]
    # ```
    def mask_by_loc!(& : Location -> Bool) : self
      map_with_loc! { |ele, loc| (yield loc) ? ele : 0.0 }
    end

    # Returns the arithmetic mean of the grid elements.
    #
    # ```
    # grid = Grid.new({2, 3, 4}, Bounds[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
    # grid.mean # => 11.5
    # ```
    def mean : Float64
      sum / size
    end

    # Returns the arithmetic mean along *axis*. Axis is specified as an
    # integer: 0-2 refer to the direction of the first, second or third
    # basis vector, respectively.
    #
    # Raises IndexError is *axis* is out of bounds.
    #
    # ```
    # grid = Grid.new({2, 3, 4}, Bounds[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
    # grid.mean(axis: 0) # => [5.5, 17.5]
    # grid.mean(axis: 1) # => [7.5, 11.5, 15.5]
    # grid.mean(axis: 2) # => [10, 11, 12, 13]
    # grid.mean(axis: 3) # raises IndexError
    # ```
    def mean(axis : Int) : Array(Float64)
      values = Array(Float64).new @dim[axis]
      each_axial_slice(axis, reuse: true) do |slice|
        values << slice.sum / slice.size
      end
      values
    end

    # Returns the arithmetic mean along *axis* with its coordinates.
    # Axis is specified as an integer: 0-2 refer to the direction of the
    # first, second or third basis vector, respectively.
    #
    # Raises IndexError is *axis* is out of bounds.
    #
    # ```
    # grid = Grid.new({2, 3, 5}, Bounds[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
    # grid.mean(axis: 1) # => [{9.5, 0.0}, {14.5, 0.5}, {19.5, 1.0}]
    # ```
    def mean_with_coords(axis : Int) : Array(Tuple(Float64, Float64))
      delta = resolution[axis]
      i = 0
      ary = Array(Tuple(Float64, Float64)).new @dim[axis]
      each_axial_slice(axis, reuse: true) do |slice|
        ary << {slice.sum / slice.size, i * delta}
        i += 1
      end
      ary
    end

    def ni : Int32
      dim[0]
    end

    def nj : Int32
      dim[1]
    end

    def nk : Int32
      dim[2]
    end

    def resolution : Tuple(Float64, Float64, Float64)
      {ni == 1 ? 0.0 : bounds.i.size / (ni - 1),
       nj == 1 ? 0.0 : bounds.j.size / (nj - 1),
       nk == 1 ? 0.0 : bounds.k.size / (nk - 1)}
    end

    def size : Int32
      ni * nj * nk
    end

    def step(n : Int) : self
      step n, n, n
    end

    def step(di : Int, dj : Int, dk : Int) : self
      raise ArgumentError.new "Invalid step size" unless di > 0 && dj > 0 && dk > 0
      new_ni = ni // di
      new_ni += 1 if new_ni % di > 0
      new_nj = nj // dj
      new_nj += 1 if new_nj % dj > 0
      new_nk = nk // dk
      new_nk += 1 if new_nk % dk > 0
      Grid.new({new_ni, new_nj, new_nk}, bounds) do |i, j, k|
        unsafe_fetch unsafe_index(Location.new(i * di, j * dj, k * dk))
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
    def unsafe_fetch(i : Int) : Float64
      @buffer[i]
    end

    @[AlwaysInline]
    def unsafe_fetch(loc : Location) : Float64
      unsafe_fetch unsafe_index(loc)
    end

    private def check_dim : Nil
      raise ArgumentError.new "Invalid dimensions" unless dim.all?(&.>(0))
    end

    private def each_axial_slice(n : Int,
                                 size : Int,
                                 reuse : Array(Float64) | Bool,
                                 & : Array(Float64), Int32 ->) : Nil
      buffer = reuse.is_a?(Array) ? reuse.clear : Array(Float64).new(size)
      n.times do |i|
        yield buffer, i
        buffer = reuse ? buffer.clear : Array(Float64).new(size)
      end
    end

    @[AlwaysInline]
    private def unsafe_coords_at(loc : Location) : Vector
      vi = ni == 1 ? Vector.zero : bounds.i / (ni - 1)
      vj = nj == 1 ? Vector.zero : bounds.j / (nj - 1)
      vk = nk == 1 ? Vector.zero : bounds.k / (nk - 1)
      origin + loc[0] * vi + loc[1] * vj + loc[2] * vk
    end

    @[AlwaysInline]
    private def unsafe_index(loc : Location) : Int
      loc[0] * nj * nk + loc[1] * nk + loc[2]
    end

    @[AlwaysInline]
    private def unsafe_loc_at(i_ : Int) : Location
      i = i_ // (nj * nk)
      j = (i_ // nk) % nj
      k = i_ % nk
      {i, j, k}
    end
  end
end
