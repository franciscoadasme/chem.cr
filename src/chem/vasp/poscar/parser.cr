module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Parser < IO::Parser
    include IO::PullParser

    @coord_system = CoordinateSystem::Fractional
    @lattice = Lattice[0, 0, 0]

    def initialize(@io : ::IO)
    end

    def each_structure(&block : Structure ->)
      yield parse
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      yield parse if indexes.size == 1 && indexes == 0
    end

    def parse : Structure
      builder = Structure::Builder.new
      builder.title read_line

      @lattice = builder.lattice self
      elements = parse_elements
      has_constraints = parse_selective_dynamics
      @coord_system = CoordinateSystem.new self

      elements.each do |element|
        atom = builder.atom of: element, at: read_coords
        atom.constraint = Constraint.new self if has_constraints
      end

      builder.build
    end

    private def parse_elements : Array(PeriodicTable::Element)
      skip_whitespace
      fail "Expected element symbols (vasp 5+)" if peek_char.number?
      elements = scan_delimited(&.letter?).map { |symbol| PeriodicTable[symbol] }
      counts = read_multiple_int
      fail "Mismatch between element symbols and counts" if elements.size != counts.size
      elements.map_with_index { |ele, i| [ele] * counts[i] }.flatten
    end

    private def parse_selective_dynamics : Bool
      skip_whitespace
      if peek_char.downcase == 's'
        skip_line
        true
      else
        false
      end
    end

    def read_bool : Bool
      Bool.new self
    end

    # TODO check whether using a tuple and manual math would speed up the parsing
    private def read_coords : Spatial::Vector
      coords = read_vector
      case @coord_system
      when .cartesian?
        coords * @lattice.scale_factor
      when .fractional?
        a = coords.x * @lattice.a
        b = coords.y * @lattice.b
        c = coords.z * @lattice.c
        a + b + c
      else
        raise "BUG: unreachable"
      end
    end

    def read_vector : Spatial::Vector
      Spatial::Vector.new self
    end
  end
end
