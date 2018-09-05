module Chem::Analysis::Spatial
  class KDTree
    private class Node
      getter axis : Int32
      getter atom_index : Int32
      getter coords : Geometry::Vector
      getter left : Node?
      getter right : Node?

      def initialize(@axis, @atom_index, @coords, @left = nil, @right = nil)
      end

      def children_sorted_by_proximity(to coords : Geometry::Vector) : Tuple(Node?, Node?)
        if coords[@axis] <= value
          {left, right}
        else
          {right, left}
        end
      end

      def distance(to point : Geometry::Vector) : Float64
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

    def nearest(to point : Geometry::Vector, neighbors count : Int32 = 1) : Array(Int32)
      neighbors = Array(Tuple(Int32, Float64)).new count
      search @root, point, count, neighbors
      neighbors.map &.[0]
    end

    def nearest(to point : Geometry::Vector, within radius : Float64) : Array(Int32)
      neighbors = [] of Tuple(Int32, Float64)
      search @root, point, radius ** 2 do |atom_index, distance|
        neighbors << {atom_index, distance}
      end
      neighbors.sort! { |a, b| a[1] <=> b[1] }
      neighbors.map &.[0]
    end

    def nearest(to point : Geometry::Vector,
                within radius : Float64,
                &block : Int32, Float64 ->) : Nil
      search @root, point, radius ** 2, &block
    end

    private def build_tree(atoms : Array(Atom), depth : Int32 = 0) : Node?
      return if atoms.empty?

      axis = depth % DIMENSIONS

      atoms.sort! { |a, b| a.coords[axis] <=> b.coords[axis] }
      middle = atoms.size / 2

      Node.new axis,
        atoms[middle].index,
        atoms[middle].coords,
        build_tree(atoms[0...middle], depth + 1),
        build_tree(atoms[(middle + 1)..-1], depth + 1)
    end

    private def search(node : Node,
                       point : Geometry::Vector,
                       max_neighbors : Int32,
                       neighbors : Array(Tuple(Int32, Float64))) : Nil
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
                       point : Geometry::Vector,
                       radius : Float64,
                       &block : Int32, Float64 -> Nil) : Nil
      return unless node

      distance = node.coords.squared_distance to: point
      yield node.atom_index, distance if distance <= radius

      return if node.leaf?

      next_node, other = node.children_sorted_by_proximity to: point
      search next_node, point, radius, &block

      search other, point, radius, &block if other && node.distance(to: point) <= radius
    end

    private def update_neighbors(node : Node,
                                 point : Geometry::Vector,
                                 max_neighbors : Int32,
                                 neighbors : Array(Tuple(Int32, Float64))) : Nil
      distance = node.coords.squared_distance to: point
      if neighbors.size < max_neighbors
        neighbors << {node.atom_index, distance}
        neighbors.sort! { |a, b| a[1] <=> b[1] }
      elsif distance < neighbors.last[1]
        neighbors.pop
        neighbors << {node.atom_index, distance}
        neighbors.sort! { |a, b| a[1] <=> b[1] }
      end
    end
  end
end
