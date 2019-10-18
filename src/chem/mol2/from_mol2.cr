module Chem
  class Structure::Builder
    def atom(pull : Mol2::Parser) : Atom
      pull.skip_index
      name = pull.scan_in_set "a-zA-Z0-9"
      coords = Spatial::Vector.new pull
      element = PeriodicTable[pull.skip_spaces.scan_in_set("A-z")]
      pull.skip('.').skip_in_set("A-z0-9").skip_spaces
      unless pull.check(&.whitespace?)
        resid = pull.read_int
        resname = pull.skip_spaces.scan_in_set "A-z0-9"
        residue resname[..2], resid
      end
      charge = pull.read_float unless pull.skip_spaces.check(&.whitespace?)
      atom name, coords, element: element, partial_charge: (charge || 0.0)
    end
  end

  struct Spatial::Vector
    def initialize(pull : Mol2::Parser)
      @x = pull.read_float
      @y = pull.read_float
      @z = pull.read_float
    end
  end
end
