module Chem
  class Structure::Builder
    def atom(pull : Mol2::PullParser) : Atom
      pull.skip(/ *\d+ */)
      name = pull.scan_until(/\s/).to_s.rstrip
      coords = Spatial::Vector.new pull
      element = PeriodicTable[pull.skip_whitespace.scan(/[A-Za-z]/).to_s]
      pull.skip(/(\.[a-z0-9]+)? */)
      unless pull.peek.whitespace?
        resid = pull.read_int
        resname = pull.skip_whitespace.scan_until(/\s/).to_s.rstrip
        residue resname[..2], resid
      end
      charge = pull.read_float unless pull.skip(/ +/).peek.whitespace?
      atom name, coords, element: element, partial_charge: (charge || 0.0)
    end
  end

  struct Spatial::Vector
    def initialize(pull : Mol2::PullParser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
