module Chem
  class Structure::Builder
    def atom(pull : XYZ::PullParser) : Atom
      pull.skip_whitespace
      ele = pull.scan(/[A-Z][a-z]?/).to_s
      atom PeriodicTable[ele], Spatial::Vector.new(pull)
    end
  end

  struct Spatial::Vector
    def initialize(pull : XYZ::PullParser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
