module Chem
  class Structure::Builder
    def atom(pull : XYZ::Parser) : Atom
      pull.skip_whitespace
      ele = pull.scan &.letter?
      atom PeriodicTable[ele], Spatial::Vector.new(pull)
    end
  end

  struct Spatial::Vector
    def initialize(pull : XYZ::Parser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
