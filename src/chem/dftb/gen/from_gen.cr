module Chem
  class Structure::Builder
    def atom(pull : DFTB::Gen::Parser) : Atom
      pull.skip_spaces.skip(&.number?).skip_spaces
      ele = pull.parse_element
      vec = Spatial::Vector.new pull
      pull.skip_line
      atom ele, vec
    end

    def lattice(pull : DFTB::Gen::Parser) : Lattice
      lattice do
        pull.skip_line
        a Spatial::Vector.new pull
        b Spatial::Vector.new pull
        c Spatial::Vector.new pull
      end
    end
  end

  struct Spatial::Vector
    def initialize(pull : DFTB::Gen::Parser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
