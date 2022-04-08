module Chem::Spatial
  class KDTree
    @root : Node

    def initialize(points : Array(Vec3))
      points_with_index = points.map_with_index { |vec, i| {vec, i} }
      if root = KDTree.build_tree(points_with_index, 0...points.size, depth: 0)
        @root = root
      else
        raise ArgumentError.new("Empty collection")
      end
    end

    protected def self.build_tree(
      points_with_index : Array(Tuple(Vec3, Int32)),
      range : Range(Int, Int),
      depth : Int32
    ) : Node?
      start, stop = range.begin, range.end
      stop -= 1 if range.exclusive?
      size = stop - start + 1
      return if size == 0

      axis = depth % 3
      if size > 1
        points_with_index.sort!(range) do |(u, _), (v, _)|
          u.unsafe_fetch(axis) <=> v.unsafe_fetch(axis)
        end
        middle = start + size // 2
        point, index = points_with_index.unsafe_fetch(middle)
        Node.new(
          axis,
          index,
          point,
          build_tree(points_with_index, start...middle, depth + 1),
          build_tree(points_with_index, (middle + 1)..stop, depth + 1)
        )
      else
        point, index = points_with_index.unsafe_fetch(start)
        Node.new(axis, index, point)
      end
    end

    def self.new(points : Array(Vec3), cell : Parallelepiped?)
      if cell
        PeriodicKDTree.new(points, cell)
      else
        new points
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

    def each_neighbor(pos : Vec3, *, within radius : Number, &block : Int32, Float64 ->) : Nil
      search(@root, pos, radius ** 2, &block)
    end

    def nearest(pos : Vec3) : Int32
      neighbors(pos, 1).first
    end

    def nearest_with_distance(pos : Vec3) : {Int32, Float64}
      neighbors_with_distances(pos, 1).first
    end

    def neighbors(pos : Vec3, count : Int) : Array(Int32)
      neighbors_with_distances(pos, count).map(&.[0])
    end

    def neighbors(pos : Vec3, *, within radius : Number) : Array(Int32)
      neighbors_with_distances(pos, within: radius).map(&.[0])
    end

    def neighbors_with_distances(pos : Vec3, count : Int) : Array({Int32, Float64})
      neighbors = Array(Tuple(Int32, Float64)).new(count)
      search(@root, pos, count, neighbors)
      neighbors.sort_by!(&.[1])
    end

    def neighbors_with_distances(
      pos : Vec3, *,
      within radius : Number
    ) : Array({Int32, Float64})
      neighbors = [] of {Int32, Float64}
      each_neighbor(pos, within: radius) do |index, dis2|
        neighbors << {index, dis2}
      end
      neighbors.sort_by!(&.[1])
    end

    private def search(node : Node,
                       pos : Vec3,
                       count : Int32,
                       neighbors : Array(Tuple(Int32, Float64))) : Nil
      left, right = node.succ(pos)
      search(left, pos, count, neighbors) if left
      if right && (neighbors.size < count || node.dis2(pos) < neighbors.last[1])
        search(right, pos, count, neighbors)
      end

      # update neighbors
      dis2 = Spatial.distance2(node.pos, pos)
      if neighbors.size < count || dis2 < neighbors.last[1]
        neighbors.pop if neighbors.size >= count
        if i = neighbors.bsearch_index { |a| a[1] > dis2 }
          neighbors.insert i, {node.index, dis2}
        else
          neighbors << {node.index, dis2}
        end
      end
    end

    private def search(node : Node,
                       pos : Vec3,
                       radius : Number,
                       &block : Int32, Float64 -> Nil) : Nil
      dis2 = Spatial.distance2(node.pos, pos)
      yield node.index, dis2 if dis2 <= radius

      left, right = node.succ(pos)
      search(left, pos, radius, &block) if left
      search(right, pos, radius, &block) if right && node.dis2(pos) <= radius
    end

    private class Node
      getter axis : Int32
      getter index : Int32
      getter pos : Vec3
      getter left : Node?
      getter right : Node?

      def initialize(@axis : Int32,
                     @index : Int32,
                     @pos : Vec3,
                     @left : Node? = nil,
                     @right : Node? = nil)
      end

      def >(pos : Vec3) : Bool
        case @axis
        when 0 then @pos.x > pos.x
        when 1 then @pos.y > pos.y
        when 2 then @pos.z > pos.z
        else        false
        end
      end

      def dis2(pos : Vec3) : Float64
        case @axis
        when 0 then (pos.x - @pos.x) ** 2
        when 1 then (pos.y - @pos.y) ** 2
        when 2 then (pos.z - @pos.z) ** 2
        else        Float64::NAN
        end
      end

      def leaf? : Bool
        @left.nil? && @right.nil?
      end

      def succ(pos : Vec3) : Tuple(Node?, Node?)
        if leaf?
          {nil, nil}
        elsif @right.nil? || self > pos
          {@left, @right}
        else
          {@right, @left}
        end
      end
    end
  end

  class PeriodicKDTree < KDTree
    def initialize(points : Array(Vec3), @cell : Parallelepiped)
      points.map! { |vec| @cell.wrap(vec) }
      super points
    end

    private def each_image(pos : Vec3, radii : Size3, & : Vec3 ->)
      fradii = (radii / @cell.size).clamp(0.0, 0.5 - Float64::EPSILON)

      fpos = @cell.fract(pos).wrap
      x_sense = case fpos.x
                when 0..fradii.x       then 1
                when (1 - fradii.x)..1 then -1
                else                        0
                end
      y_sense = case fpos.y
                when 0..fradii.y       then 1
                when (1 - fradii.y)..1 then -1
                else                        0
                end
      z_sense = case fpos.z
                when 0..fradii.z       then 1
                when (1 - fradii.z)..1 then -1
                else                        0
                end
      x_sense.abs.downto(0) do |i|
        y_sense.abs.downto(0) do |j|
          z_sense.abs.downto(0) do |k|
            img_idx = Vec3[i * x_sense, j * y_sense, k * z_sense]
            yield @cell.cart(fpos + img_idx)
          end
        end
      end
    end

    def each_neighbor(pos : Vec3, *, within radius : Number, &block : Int32, Float64 ->) : Nil
      raise ArgumentError.new("Negative radius") unless radius >= 0
      r2 = radius ** 2
      each_image(pos, Size3[radius, radius, radius]) do |pos|
        search(@root, pos, r2, &block)
      end
    end

    def neighbors_with_distances(pos : Vec3, count : Int) : Array({Int32, Float64})
      neighbors = Array(Tuple(Int32, Float64)).new(count)
      each_image(pos, @cell.size / 0.5) do |pos|
        search(@root, pos, count, neighbors)
      end
      neighbors.sort_by!(&.[1])
    end

    def neighbors_with_distances(
      pos : Vec3, *,
      within radius : Number
    ) : Array({Int32, Float64})
      neighbors = [] of {Int32, Float64}
      each_neighbor(pos, within: radius) do |index, dis2|
        neighbors << {index, dis2}
      end
      neighbors.sort_by!(&.[1])
    end
  end
end
