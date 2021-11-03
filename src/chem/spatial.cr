require "./spatial/affine"
require "./spatial/size3"
require "./spatial/vec3"
require "./spatial/mat3"

require "./spatial/bounds"
require "./spatial/grid"
require "./spatial/quat"

require "./spatial/coordinates_proxy"
require "./spatial/kdtree"
require "./spatial/measure"
require "./spatial/pbc"

module Chem::Spatial
  alias FloatTriple = Tuple(Float64, Float64, Float64)
  alias NumberTriple = Tuple(Number::Primitive, Number::Primitive, Number::Primitive)

  # :nodoc:
  PRINT_PRECISION = 7

  class Error < Exception; end

  class NotPeriodicError < Error
    def initialize(message = "Coordinates are not periodic")
      super(message)
    end
  end
end
