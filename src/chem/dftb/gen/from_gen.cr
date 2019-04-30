module Chem
  class Structure::Builder
    def atom(pull : DFTB::Gen::PullParser) : Atom
      pull.skip(/\s*\d+ */)
      atom of: pull.parse_element, at: Spatial::Vector.new(pull)
    end

    def lattice(pull : DFTB::Gen::PullParser) : Lattice
      lattice do
        pull.skip_whitespace
        pull.skip_line
        a Spatial::Vector.new pull
        b Spatial::Vector.new pull
        c Spatial::Vector.new pull
      end
    end
  end

  struct Spatial::Vector
    def initialize(pull : DFTB::Gen::PullParser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
