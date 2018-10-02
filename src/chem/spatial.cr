require "./spatial/*"

module Chem::Spatial
  extend self

  def angle(v1 : Vector, v2 : Vector) : Float64
    Math.atan2(v1.cross(v2).magnitude, v1.dot(v2)).degrees
  end

  def distance(v1 : Vector, v2 : Vector) : Float64
    Math.sqrt squared_distance(v1, v2)
  end

  @[AlwaysInline]
  def squared_distance(v1 : Vector, v2 : Vector) : Float64
    (v1.x - v2.x)**2 + (v1.y - v2.y)**2 + (v1.z - v2.z)**2
  end
end
