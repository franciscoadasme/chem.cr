# TODO: make compatible with `Positions3Proxy`
struct Chem::Spatial::Positions3
  include Indexable(Vec3)

  getter! cell : Parallelepiped?

  @pos : Slice(Vec3)

  delegate size, unsafe_fetch, to: @pos

  def initialize(@pos : Slice(Vec3), @cell : Parallelepiped? = nil)
  end
end
