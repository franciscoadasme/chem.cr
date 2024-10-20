module Chem::Spatial
  # TODO: add support for non-cubic grids (use cell instead of bounds?)
  #       - i to pos: origin.x + (i / nx) * cell.a
  #       - pos to i: ?
  # TODO: implement functionality from vmd's volmap
  class Grid
    include Indexable(Float64)

    alias Dimensions = Tuple(Int32, Int32, Int32)
    alias Location = Tuple(Int32, Int32, Int32)
    record Info, bounds : Parallelepiped, dim : Dimensions

    getter bounds : Parallelepiped
    getter dim : Dimensions
    getter source_file : Path?

    @buffer : Pointer(Float64)

    delegate includes?, origin, volume, to: @bounds

    def initialize(@dim : Dimensions,
                   @bounds : Parallelepiped,
                   source_file : String | Path | Nil = nil)
      check_dim
      @buffer = Pointer(Float64).malloc size
      source_file = Path.new(source_file) if source_file.is_a?(String)
      @source_file = source_file.try(&.expand)
    end

    def initialize(@dim : Dimensions,
                   @bounds : Parallelepiped,
                   initial_value : Float64,
                   source_file : String | Path | Nil = nil)
      check_dim
      @buffer = Pointer(Float64).malloc size, initial_value
      source_file = Path.new(source_file) if source_file.is_a?(String)
      @source_file = source_file.try(&.expand)
    end

    def self.[](ni : Int, nj : Int, nk : Int) : self
      new({ni.to_i, nj.to_i, nk.to_i}, Parallelepiped.cubic(0))
    end

    def self.atom_distance(structure : Structure,
                           dim : Dimensions,
                           bounds : Parallelepiped? = nil) : self
      grid = new dim, (bounds || structure.pos.bounds)
      pos = structure.pos.to_a
      kdtree = KDTree.new(pos, structure.cell?)
      grid.map_with_pos! do |_, vec|
        Math.sqrt kdtree.nearest_with_distance(vec)[1]
      end
    end

    # Returns a grid filled with the distances to the nearest atom. It will have the
    # same bounds and points as *other*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # info = Grid::Info.new Parallelepiped[1.5, 2.135, 6.12], {10, 10, 10}
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
    def self.build(info : Info,
                   source_file : String | Path | Nil = nil,
                   & : Pointer(Float64), Int32 ->) : self
      grid = new info.dim, info.bounds, source_file
      yield grid.to_unsafe, grid.size
      grid
    end

    def self.build(dim : Dimensions,
                   bounds : Parallelepiped,
                   source_file : String | Path | Nil = nil,
                   & : Pointer(Float64), Int32 ->) : self
      grid = new dim, bounds, source_file
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

    # Reads a grid from *io* in the given *format*. See also:
    # `IO#read_bytes`. Raises `IO::EOFError` if there is missing data.
    def self.from_io(io : IO, format : IO::ByteFormat) : self
      bounds = io.read_bytes Parallelepiped, format
      bytesize = io.read_bytes Int32, format
      source_file = io.read_string(bytesize) if bytesize > 0
      dim = {0, 0, 0}.map { io.read_bytes(Int32, format) }
      build(dim, bounds, source_file) do |buffer, size|
        bytes = buffer.to_slice(size).to_unsafe_bytes
        io.read_fully bytes
      end
    end

    def self.new(dim : Dimensions,
                 bounds : Parallelepiped,
                 source_file : String | Path | Nil = nil,
                 &block : Location -> Number)
      new(dim, bounds, source_file).map_with_loc! do |_, loc|
        (yield loc).to_f
      end
    end

    # TODO: add more tests
    # FIXME: check delta calculation (grid.resolution.min / 2 shouldn't be enough?)
    def self.vdw_mask(structure : Structure,
                      dim : Dimensions,
                      bounds : Parallelepiped? = nil,
                      delta : Float64 = 0.02) : self
      grid = new dim, (bounds || structure.pos.bounds)
      delta = Math.min delta, grid.resolution.min / 2
      atoms = structure.atoms
      kdtree = KDTree.new(atoms.map(&.pos), structure.cell?)
      vdw_cutoff = structure.atoms.max_of &.vdw_radius
      # grid.map_with_pos! do |_, vec|
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
      structure.atoms.each do |atom|
        grid.each_loc(atom.pos, atom.vdw_radius + delta) do |loc, d|
          too_close = false
          kdtree.each_neighbor(grid.pos_at(loc), within: vdw_cutoff) do |index, od|
            other = atoms.unsafe_fetch(index)
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
    # info = Grid::Info.new Parallelepiped[5.213, 6.823, 10.352], {20, 25, 40}
    # grid = Grid.vdw_mask structure, info.dim, info.bounds
    # Grid.vdw_mask_like(info, structure) == grid # => true
    # ```
    def self.vdw_mask_like(other : self | Info,
                           structure : Structure,
                           delta : Float64 = 0.02) : self
      vdw_mask structure, other.dim, other.bounds, delta
    end

    def ==(rhs : self) : Bool
      return false unless @dim == rhs.dim &&
                          @bounds == rhs.bounds &&
                          @source_file == rhs.source_file
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
    def []?(vec : Vec3) : Float64?
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

    def pos_at(*args, **options) : Vec3
      pos_at?(*args, **options) || raise IndexError.new
    end

    def pos_at?(i : Int) : Vec3?
      if loc = loc_at?(i)
        pos_at? loc
      end
    end

    def pos_at?(i : Int, j : Int, k : Int) : Vec3?
      pos_at?(Location.new(i, j, k))
    end

    def pos_at?(loc : Location) : Vec3?
      return unless index(loc)
      unsafe_pos_at(loc)
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
    # grid = Grid.new({2, 3, 2}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 6 + j * 2 + k }
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

    def each_pos(& : Vec3 ->) : Nil
      each_loc do |loc|
        yield unsafe_pos_at(loc)
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

    def each_loc(vec : Vec3, cutoff : Number, & : Location, Float64 ->) : Nil
      return unless loc = loc_at?(vec)
      di, dj, dk = resolution.map { |ele| (cutoff / ele).to_i }
      cutoff *= cutoff
      ((loc[0] - di - 1)..(loc[0] + di + 1)).clamp(0..ni - 1).each do |i|
        ((loc[1] - dj - 1)..(loc[1] + dj + 1)).clamp(0..nj - 1).each do |j|
          ((loc[2] - dk - 1)..(loc[2] + dk + 1)).clamp(0..nk - 1).each do |k|
            new_loc = Location.new i, j, k
            d = vec.distance2 unsafe_pos_at(new_loc)
            yield new_loc, Math.sqrt(d) if d < cutoff
          end
        end
      end
    end

    def each_with_pos(& : Float64, Vec3 ->) : Nil
      each_index do |i|
        yield unsafe_fetch(i), unsafe_pos_at(unsafe_loc_at(i))
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

    def index(vec : Vec3) : Int32?
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

    def loc_at?(vec : Vec3) : Location?
      return unless vec.in?(bounds)
      vec = bounds.fract(vec - origin)
      vec = vec * (Vec3[*@dim] - 1)
      {vec.x, vec.y, vec.z}.map(&.round.to_i)
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

    def map_with_pos(& : Float64, Vec3 -> Number) : self
      dup.map_with_pos! do |ele, vec|
        yield ele, vec
      end
    end

    def map_with_pos!(& : Float64, Vec3 -> Number) : self
      each_with_index do |ele, i|
        @buffer[i] = (yield ele, unsafe_pos_at(unsafe_loc_at(i))).to_f
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[10, 10, 10]) { |i, j, k| i + j + k }
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
    # grid = Grid.new({2, 2, 3}, Parallelepiped[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
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
    # grid = Grid.new({2, 2, 3}, Parallelepiped[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) / 5 }
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[10, 10, 10]) { |i, j, k| i + j + k }
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
    # grid = Grid.new({2, 2, 3}, Parallelepiped[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
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
    # grid = Grid.new({2, 2, 3}, Parallelepiped[1, 1, 1]) { |i, j, k| (i + j + k) / 5 }
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a                        # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_pos(&.x.==(0)).to_a # => [1, 1, 1, 1, 0, 0, 0, 0]
    # grid.to_a                        # => [0, 1, 2, 3, 4, 5, 6, 7]
    # ```
    def mask_by_pos(& : Vec3 -> Bool) : self
      map_with_pos { |_, vec| (yield vec) ? 1.0 : 0.0 }
    end

    # Masks a grid by coordinates. Coordinates for which the passed block returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask_by_pos { ... }`
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Parallelepiped[5, 5, 5]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_pos! { |vec| vec.y == 5 }
    # grid.to_a # => [0, 0, 2, 3, 0, 0, 6, 7]
    # ```
    def mask_by_pos!(& : Vec3 -> Bool) : self
      map_with_pos! { |ele, vec| (yield vec) ? ele : 0.0 }
    end

    # Returns a grid mask. Indexes for which the passed block returns `true` are set to
    # 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Parallelepiped[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 4 + j * 2 + k }
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
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
    # grid = Grid.new({2, 2, 2}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 4 + j * 2 + k }
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
    # grid = Grid.new({2, 3, 4}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
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
    # grid = Grid.new({2, 3, 4}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
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
    # grid = Grid.new({2, 3, 5}, Parallelepiped[1, 1, 1]) { |i, j, k| i * 12 + j * 4 + k }
    # grid.mean(axis: 1) # => [{9.5, 0.0}, {14.5, 0.5}, {19.5, 1.0}]
    # ```
    def mean_with_pos(axis : Int) : Array(Tuple(Float64, Float64))
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

    def resolution : FloatTriple
      size = bounds.size
      {ni == 1 ? 0.0 : size[0] / (ni - 1),
       nj == 1 ? 0.0 : size[1] / (nj - 1),
       nk == 1 ? 0.0 : size[2] / (nk - 1)}
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

    # Writes the binary representation of the grid to *io* in the given
    # *format*. See also `IO#write_bytes`. Raises `ArgumentError` is the
    # encoding is not UTF-8.
    def to_io(io : IO, format : IO::ByteFormat = :system_endian) : Nil
      raise ArgumentError.new("Invalid IO encoding") unless io.encoding == "UTF-8"
      io.write_bytes @bounds, format
      if str = @source_file.try(&.to_s)
        io.write_bytes str.bytesize, format
        io.write_string str.to_slice
      else
        io.write_bytes 0, format
      end
      @dim.each &.to_io(io, format)
      io.write @buffer.to_slice(size).to_unsafe_bytes
    end

    def to_unsafe : Pointer(Float64)
      @buffer
    end

    @[AlwaysInline]
    def unsafe_fetch(index : Int) : Float64
      @buffer[index]
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
    private def unsafe_pos_at(loc : Location) : Vec3
      vec = origin
      {% for i in 0..2 %}
        vec += loc[{{i}}] * bounds.basisvec[{{i}}] / (@dim[{{i}}] - 1) if @dim[{{i}}] > 1
      {% end %}
      vec
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
