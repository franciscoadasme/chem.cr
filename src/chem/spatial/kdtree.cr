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

      def children_sorted_by_proximity(to coords : Vector) : Tuple(Node?, Node?)
        if coords[@axis] <= value
          {left, right}
        else
          {right, left}
        end
      end

      def distance(to point : Vector) : Float64
        (point[@axis] - value) ** 2
      end

      def leaf?
        @left.nil? && @right.nil?
      end

      def value
        @coords[@axis]
      end
    end

    DIMENSIONS = 3

    @root : Node

    def initialize(atoms : AtomView)
      if root = build_tree atoms.to_a
        @root = root
      else
        raise "kdtree construction failed"
      end
    end

    def nearest(to point : Vector, neighbors count : Int32 = 1) : Array(Atom)
      neighbors = Array(Tuple(Atom, Float64)).new count
      search @root, point, count, neighbors
      neighbors.map &.[0]
    end

    def nearest(to point : Vector, within radius : Float64) : Array(Atom)
      neighbors = [] of Tuple(Atom, Float64)
      search @root, point, radius ** 2 do |atom, distance|
        neighbors << {atom, distance}
      end
      neighbors.sort! { |a, b| a[1] <=> b[1] }
      neighbors.map &.[0]
    end

    def nearest(to point : Vector,
                within radius : Float64,
                &block : Atom, Float64 ->) : Nil
      search @root, point, radius ** 2, &block
    end

    private def build_tree(atoms : Array(Atom), depth : Int32 = 0) : Node?
      return if atoms.empty?

      axis = depth % DIMENSIONS

      atoms.sort! { |a, b| a.coords[axis] <=> b.coords[axis] }
      middle = atoms.size / 2

      Node.new axis,
        atoms[middle],
        atoms[middle].coords,
        build_tree(atoms[0...middle], depth + 1),
        build_tree(atoms[(middle + 1)..-1], depth + 1)
    end

    private def search(node : Node,
                       point : Vector,
                       max_neighbors : Int32,
                       neighbors : Array(Tuple(Atom, Float64))) : Nil
      if point[node.axis] < node.value
        if left = node.left
          search left, point, max_neighbors, neighbors
        end
        if (right = node.right) && node.distance(to: point) < neighbors.last[1]
          search right, point, max_neighbors, neighbors
        end
      else
        if right = node.right
          search right, point, max_neighbors, neighbors
        end
        if (left = node.left) && node.distance(to: point) < neighbors.last[1]
          search left, point, max_neighbors, neighbors
        end
      end

      update_neighbors node, point, max_neighbors, neighbors
    end

    private def search(node : Node?,
                       point : Vector,
                       radius : Float64,
                       &block : Atom, Float64 -> Nil) : Nil
      return unless node

      distance = Spatial.squared_distance node.coords, point
      yield node.atom, distance if distance <= radius

      return if node.leaf?

      next_node, other = node.children_sorted_by_proximity to: point
      search next_node, point, radius, &block

      search other, point, radius, &block if other && node.distance(to: point) <= radius
    end

    private def update_neighbors(node : Node,
                                 point : Vector,
                                 max_neighbors : Int32,
                                 neighbors : Array(Tuple(Atom, Float64))) : Nil
      distance = Spatial.squared_distance node.coords, point
      if neighbors.size < max_neighbors
        neighbors << {node.atom, distance}
        neighbors.sort! { |a, b| a[1] <=> b[1] }
      elsif distance < neighbors.last[1]
        neighbors.pop
        neighbors << {node.atom, distance}
        neighbors.sort! { |a, b| a[1] <=> b[1] }
      end
    end
  end
end
