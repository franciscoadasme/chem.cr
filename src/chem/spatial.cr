require "./spatial/affine"
require "./spatial/size"
require "./spatial/vector"

require "./spatial/basis"
require "./spatial/bounds"
require "./spatial/grid"
require "./spatial/quaternion"

require "./spatial/coordinates_proxy"
require "./spatial/hlxparams"
require "./spatial/kdtree"
require "./spatial/measure"
require "./spatial/pbc"

module Chem::Spatial
  extend self

  class Error < Exception; end

  class NotPeriodicError < Error
    def initialize(message = "Coordinates are not periodic")
      super(message)
    end
  end
end
