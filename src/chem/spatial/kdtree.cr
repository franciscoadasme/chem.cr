module Chem::Spatial
  # TODO: refactor to a generic such that #initialize accepts a list of
  # coordinates (or a Coordinates object) and a list of associated
  # object to be returned. Alternatively, it could return the index of
  # the neighbors, which can then be used get the associated object
  # (however, it would require to be indexed).
  class KDTree
    private class Node
      getter axis : Int32
      getter atom : Atom
      getter coords : Vec3
      getter left : Node?
      getter right : Node?

      def initialize(@axis, @atom, @coords, @left = nil, @right = nil)
      end

      def distance(coords : Vec3) : Float64
        (coords[@axis] - @coords[@axis]) ** 2
      end

      def leaf?
        @left.nil? && @right.nil?
      end

      def next(coords : Vec3) : Tuple(Node?, Node?)
        if leaf?
          {nil, nil}
        elsif @right.nil? || coords[@axis] <= @coords[@axis]
          {@left, @right}
        else
          {@right, @left}
        end
      end
    end

    DIMENSIONS = 3

    @root : Node

    private def initialize(atoms : Array(Tuple(Vec3, Atom)), @cell : Parallelepiped? = nil)
      if root = build_tree atoms, 0...atoms.size
        @root = root
      else
        raise "kdtree construction failed"
      end
    end

    def self.new(structure : Structure, **options) : self
      new structure, structure.periodic?, **options
    end

    def self.new(structure : Structure, periodic : Bool, **options)
      if periodic
        raise NotPeriodicError.new unless cell = structure.cell
        new structure.atoms, cell, **options
      else
        new structure.atoms
      end
    end

    # FIXME: this is incorrect because issues of
    # PBC.each_adjacent_image. Either fix that or use an alternative
    # approach to include periodicity like
    # github.com/patvarilly/periodic_kdtree, where they save the wrapped
    # coordinates and search for neighbors of every possible image of
    # the query. While it's more memory efficient and tree creation is
    # faster, query could be up to 9 times slower since all images must
    # be tested (check _gen_relevant_images of the aforementioned code).
    # Another alternative is to generate the adjacent coordinates here
    # to avoid the current limitations of the API, where coordinates
    # cannot be wrapped without modifying original data. Save wrapped
    # coordinates augmented with adjacent images and the cell, and then
    # wrap the query and search for neighbors.

    def self.new(atoms : Enumerable(Atom)) : self
      new atoms.map { |atom| {atom.coords, atom} }
    end

    def self.new(atoms : Enumerable(Atom), cell : Parallelepiped) : self
      arr = Array({Vec3, Atom}).new(atoms.size)
      atoms.each do |atom|
        fvec = cell.fract(atom.coords).wrap
        x_sense = fvec.x < 0.5 ? 1 : -1
        y_sense = fvec.y < 0.5 ? 1 : -1
        z_sense = fvec.z < 0.5 ? 1 : -1
        x_sense.abs.downto(0) do |i|
          y_sense.abs.downto(0) do |j|
            z_sense.abs.downto(0) do |k|
              img_idx = Vec3[i * x_sense, j * y_sense, k * z_sense]
              arr << {cell.cart(fvec + img_idx), atom}
            end
          end
        end
      end
      new arr, cell
    end

    def self.new(atoms : Enumerable(Atom), cell : Parallelepiped, radius : Number) : self
      raise ArgumentError.new("Negative radius") unless radius >= 0
      fradii = StaticArray(Float64, 3).new do |i|
        (radius / cell.size[i]).clamp(0.0, 0.5 - Float64::EPSILON)
      end

      arr = Array({Vec3, Atom}).new(atoms.size)
      atoms.each do |atom|
        fvec = cell.fract(atom.coords).wrap

        {% begin %}
          {% for var, i in %w(x y z) %}
            {{var.id}}_sense = case fvec.{{var.id}}
                               when 0..fradii[{{i}}]       then 1
                               when (1 - fradii[{{i}}])..1 then -1
                               else                        0
                               end
          {% end %}

          x_sense.abs.downto(0) do |i|
            y_sense.abs.downto(0) do |j|
              z_sense.abs.downto(0) do |k|
                img_idx = Vec3[i * x_sense, j * y_sense, k * z_sense]
                arr << {cell.cart(fvec + img_idx), atom}
              end
            end
          end
        {% end %}
      end
      new arr, cell
    end

    def each_neighbor(of atom : Atom,
                      *,
                      within radius : Float64,
                      &block : Atom, Float64 ->) : Nil
      coords = atom.coords
      if cell = @cell
        coords = cell.wrap(coords)
      end
      search @root, coords, radius ** 2 do |other, distance|
        block.call(other, distance) if atom != other
      end
    end

    def each_neighbor(of coords : Vec3,
                      *,
                      within radius : Float64,
                      &block : Atom, Float64 ->) : Nil
      if cell = @cell
        coords = cell.wrap(coords)
      end
      search @root, coords, radius ** 2, &block
    end

    def nearest(to atom : Atom) : Atom
      neighbors(atom.coords, count: 2)[1]
    end

    def nearest(to coords : Vec3) : Atom
      neighbors(coords, count: 1).first
    end

    def nearest_with_distance(atom : Atom | Vec3) : Tuple(Atom, Float64)
      neighbors_with_distance(atom, n: 1).first
    end

    def neighbors(of atom : Atom, *, count : Int) : Array(Atom)
      neighbors(atom.coords, count: count + 1).reject! &.==(atom)
    end

    def neighbors(of coords : Vec3, *, count : Int) : Array(Atom)
      neighbors = Array(Tuple(Atom, Float64)).new count
      if cell = @cell
        coords = cell.wrap(coords)
      end
      search @root, coords, count, neighbors
      neighbors.map &.[0]
    end

    def neighbors(of atom : Atom, *, within radius : Number) : Array(Atom)
      neighbors(atom.coords, within: radius).reject! &.==(atom)
    end

    def neighbors(of coords : Vec3, *, within radius : Number) : Array(Atom)
      neighbors = [] of Tuple(Atom, Float64)
      if cell = @cell
        coords = cell.wrap(coords)
      end
      search @root, coords, radius ** 2 do |atom, distance|
        neighbors << {atom, distance}
      end
      neighbors.sort_by!(&.[1]).map &.[0]
    end

    def neighbors_with_distance(atom : Atom, *, n : Int) : Array(Tuple(Atom, Float64))
      neighbors_with_distance(atom.coords, n: n + 1).reject! &.[0].==(atom)
    end

    def neighbors_with_distance(vec : Vec3, *, n : Int) : Array(Tuple(Atom, Float64))
      neighbors = Array(Tuple(Atom, Float64)).new n
      if cell = @cell
        vec = cell.wrap(vec)
      end
      search @root, vec, n, neighbors
      neighbors
    end

    private def build_tree(atoms : Array(Tuple(Vec3, Atom)),
                           range : Range(Int, Int),
                           depth : Int32 = 0) : Node?
      start, stop = range.begin, range.end
      stop -= 1 if range.exclusive?
      size = stop - start + 1
      return if size == 0

      axis = depth % DIMENSIONS
      return Node.new axis, atoms[start][1], atoms[start][0] if size == 1

      atoms.sort!(range) { |a, b| a[0][axis] <=> b[0][axis] }
      middle = start + size // 2
      Node.new axis,
        atoms[middle][1],
        atoms[middle][0],
        build_tree(atoms, start...middle, depth + 1),
        build_tree(atoms, (middle + 1)..stop, depth + 1)
    end

    private def search(node : Node,
                       coords : Vec3,
                       count : Int32,
                       neighbors : Array(Tuple(Atom, Float64))) : Nil
      a, b = node.next coords
      search a, coords, count, neighbors if a
      if b && (neighbors.size < count || node.distance(coords) < neighbors.last[1])
        search b, coords, count, neighbors
      end

      update_neighbors node, coords, count, neighbors
    end

    private def search(node : Node,
                       coords : Vec3,
                       radius : Number,
                       &block : Atom, Float64 -> Nil) : Nil
      distance = Spatial.distance2 node.coords, coords
      yield node.atom, distance if distance <= radius

      a, b = node.next coords
      search a, coords, radius, &block if a
      search b, coords, radius, &block if b && node.distance(coords) <= radius
    end

    private def update_neighbors(node : Node,
                                 point : Vec3,
                                 count : Int32,
                                 neighbors : Array(Tuple(Atom, Float64))) : Nil
      distance = Spatial.distance2 node.coords, point
      if neighbors.size < count || distance < neighbors.last[1]
        neighbors.pop if neighbors.size >= count
        if i = neighbors.bsearch_index { |a| a[1] > distance }
          neighbors.insert i, {node.atom, distance}
        else
          neighbors << {node.atom, distance}
        end
      end
    end
  end
end
