module Chem::Spatial
  class KDTree
    private class Node
      getter axis : Int32
      getter atom : Atom
      getter coords : Vector
      getter left : Node?
      getter right : Node?

      def initialize(@axis, @atom, @coords, @left = nil, @right = nil)
      end

      def distance(coords : Vector) : Float64
        (coords[@axis] - @coords[@axis]) ** 2
      end

      def leaf?
        @left.nil? && @right.nil?
      end

      def next(coords : Vector) : Tuple(Node?, Node?)
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

    private def initialize(atoms : Array(Tuple(Vector, Atom)))
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
        raise NotPeriodicError.new unless lattice = structure.lattice
        new structure, lattice, **options
      else
        new structure.each_atom.map { |atom| {atom.coords, atom} }.to_a
      end
    end

    def self.new(atoms : AtomCollection, lattice : Lattice? = nil, **options)
      ary = Array(Tuple(Vector, Atom)).new atoms.n_atoms
      atoms.each_atom { |atom| ary << {atom.coords, atom} }
      if lattice
        PBC.each_adjacent_image(atoms, lattice, **options) do |atom, coords|
          ary << {coords, atom}
        end
      end
      new ary
    end

    def each_neighbor(of atom : Atom,
                      *,
                      within radius : Float64,
                      &block : Atom, Float64 ->) : Nil
      search @root, atom.coords, radius ** 2 do |other, distance|
        block.call(other, distance) if atom != other
      end
    end

    def each_neighbor(of coords : Vector,
                      *,
                      within radius : Float64,
                      &block : Atom, Float64 ->) : Nil
      search @root, coords, radius ** 2, &block
    end

    def nearest(to atom : Atom) : Atom
      neighbors(atom.coords, count: 2)[1]
    end

    def nearest(to coords : Vector) : Atom
      neighbors(coords, count: 1).first
    end

    def nearest_with_distance(atom : Atom | Vector) : Tuple(Atom, Float64)
      neighbors_with_distance(atom, n: 1).first
    end

    def neighbors(of atom : Atom, *, count : Int) : Array(Atom)
      neighbors(atom.coords, count: count + 1).reject! &.==(atom)
    end

    def neighbors(of coords : Vector, *, count : Int) : Array(Atom)
      neighbors = Array(Tuple(Atom, Float64)).new count
      search @root, coords, count, neighbors
      neighbors.map &.[0]
    end

    def neighbors(of atom : Atom, *, within radius : Number) : Array(Atom)
      neighbors(atom.coords, within: radius).reject! &.==(atom)
    end

    def neighbors(of coords : Vector, *, within radius : Number) : Array(Atom)
      neighbors = [] of Tuple(Atom, Float64)
      search @root, coords, radius ** 2 do |atom, distance|
        neighbors << {atom, distance}
      end
      neighbors.sort_by!(&.[1]).map &.[0]
    end

    def neighbors_with_distance(atom : Atom, *, n : Int) : Array(Tuple(Atom, Float64))
      neighbors_with_distance(atom.coords, n: n + 1).reject! &.[0].==(atom)
    end

    def neighbors_with_distance(vec : Vector, *, n : Int) : Array(Tuple(Atom, Float64))
      neighbors = Array(Tuple(Atom, Float64)).new n
      search @root, vec, n, neighbors
      neighbors
    end

    private def build_tree(atoms : Array(Tuple(Vector, Atom)),
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
                       coords : Vector,
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
                       coords : Vector,
                       radius : Number,
                       &block : Atom, Float64 -> Nil) : Nil
      distance = Spatial.squared_distance node.coords, coords
      yield node.atom, distance if distance <= radius

      a, b = node.next coords
      search a, coords, radius, &block if a
      search b, coords, radius, &block if b && node.distance(coords) <= radius
    end

    private def update_neighbors(node : Node,
                                 point : Vector,
                                 count : Int32,
                                 neighbors : Array(Tuple(Atom, Float64))) : Nil
      distance = Spatial.squared_distance node.coords, point
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
