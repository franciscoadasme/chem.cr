# github.com/jtomschroeder/crystalline on 2018-7-13
module Crystalline
  class KDTree(T)
    class Node(T)
      property id
      property pos
      property left : Node(T)?
      property right : Node(T)?

      def initialize(@id : T, @pos : Array(T), @left = nil, @right = nil)
      end
    end

    @dimensions : Int32
    @root : Node(T)?

    def initialize(points : Hash(T, Array(T)))
      @dimensions = points[points.keys.first].size
      @root = build_tree(points.to_a)
      @nearest = [] of Array(T)
    end

    # Find k closest points to given coordinates
    def find_nearest(target : Array(T), k_nearest : Int32)
      @nearest = [] of Array(T)
      if root = @root
        nearest(root, target, k_nearest, 0)
      end
    end

    def find_nearest(target : Array(T), radius : Float64)
      @nearest = [] of Array(T)
      if root = @root
        nearest(root, target, radius ** 2, 0)
      end
    end

    def build_tree(points : Array({T, Array(T)}), depth = 0)
      return if points.empty?

      axis = depth % @dimensions

      points.sort! { |a, b| a[1][axis] <=> b[1][axis] }
      median = points.size / 2

      node = Node.new(points[median][0], points[median][1])
      node.left = build_tree(points[...median], depth + 1)
      node.right = build_tree(points[median + 1..], depth + 1)
      node
    end

    # Euclidian distance, squared, between a node and target pos
    private def distance2(node, target)
      return unless node && target
      c = node.pos[0] - target[0]
      d = node.pos[1] - target[1]
      e = node.pos[2] - target[2]
      c * c + d * d + e * e
    end

    # Update array of nearest elements if necessary
    private def check_nearest(nearest, node, target, k_nearest : Int32)
      d = distance2(node, target).as T
      if nearest.size < k_nearest || d < nearest.last[0]
        nearest.pop if nearest.size >= k_nearest
        nearest << [d, node.id]
        nearest.sort! { |a, b| a[0] <=> b[0] }
      end
      nearest
    end

    private def check_nearest(nearest, node, target, radius : Float64)
      d = distance2(node, target).as T
      nearest << [d, node.id] if d <= radius
      nearest
    end

    # Recursively find nearest coordinates, going down the appropriate branch as needed
    private def nearest(node, target, k_nearest : Int32, depth)
      axis = depth % @dimensions

      if node
        unless node.left || node.right # Leaf node
          @nearest = check_nearest(@nearest, node, target, k_nearest)
          return
        end

        # Go down the nearest split
        if !node.right || (node.left && target[axis] <= node.pos[axis])
          nearer = node.left
          further = node.right
        else
          nearer = node.right
          further = node.left
        end
        nearest(nearer, target, k_nearest, depth + 1)

        # See if we have to check other side
        if further
          if @nearest.size < k_nearest || (target[axis] - node.pos[axis]) ** 2 < @nearest.last[0]
            nearest(further, target, k_nearest, depth + 1)
          end
        end

        @nearest = check_nearest(@nearest, node, target, k_nearest)
      end
    end

    private def nearest(node, target, radius : Float64, depth)
      axis = depth % @dimensions

      if node
        unless node.left || node.right # Leaf node
          @nearest = check_nearest(@nearest, node, target, radius)
          return
        end

        # Go down the nearest split
        if !node.right || (node.left && target[axis] <= node.pos[axis])
          nearer = node.left
          further = node.right
        else
          nearer = node.right
          further = node.left
        end
        nearest(nearer, target, radius, depth + 1)

        # See if we have to check other side
        if further
          if (target[axis] - node.pos[axis]) ** 2 <= radius
            nearest(further, target, radius, depth + 1)
          end
        end

        @nearest = check_nearest(@nearest, node, target, radius)
      end
    end
  end
end

def naive_search(atoms, point, count)
  neighbors = Array({Chem::Atom, Float64}).new count
  atoms.each do |atom|
    dist = Chem::Spatial.distance2 atom.pos, point
    if neighbors.size < count
      neighbors << {atom, dist}
    elsif dist < neighbors.last[1]
      neighbors.pop
      neighbors << {atom, dist}
    end
    neighbors.sort! { |a, b| a[1] <=> b[1] }
  end
  neighbors.map &.[0]
end

def sort_search(atoms, point, count)
  atoms = atoms.sort do |a, b|
    dist_a = Chem::Spatial.distance2 a.pos, point
    dist_b = Chem::Spatial.distance2 b.pos, point
    dist_a <=> dist_b
  end
  atoms.first count
end
