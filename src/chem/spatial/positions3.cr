# TODO: make compatible with `Positions3Proxy`
struct Chem::Spatial::Positions3
  include Indexable(Vec3)

  getter! cell : Parallelepiped?

  @pos : Slice(Vec3)

  delegate size, unsafe_fetch, to: @pos

  def initialize(@pos : Slice(Vec3), @cell : Parallelepiped? = nil)
  end

  # Returns a read-only slice of the positions.
  def to_slice : Slice(Vec3)
    Slice.new @pos.to_unsafe, @pos.size, read_only: true
  end
end
