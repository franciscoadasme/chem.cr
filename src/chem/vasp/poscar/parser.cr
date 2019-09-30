module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Parser < IO::Parser
    include IO::PullParser

    getter scale_factor : Float64 = 1.0

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

      @scale_factor = read_float
      skip_line
      lattice = builder.lattice self
      elements = parse_elements
      has_constraints = parse_selective_dynamics
      fractional = parse_coordinate_system

      elements.each do |element|
        vec = read_vector
        vec = fractional ? vec.to_cartesian(lattice) : vec * @scale_factor
        atom = builder.atom of: element, at: vec
        atom.constraint = Constraint.new self if has_constraints
      end

      builder.build
    end

    private def parse_elements : Array(PeriodicTable::Element)
      skip_whitespace
      parse_exception "Expected element symbols (vasp 5+)" if check &.number?
      elements = scan_delimited(&.letter?).map { |symbol| PeriodicTable[symbol] }
      counts = Array(Int32).new(elements.size) { read_int }
      skip_line
      elements.map_with_index { |ele, i| [ele] * counts[i] }.flatten
    end

    private def parse_selective_dynamics : Bool
      skip_whitespace
      if check_in_set "sS"
        skip_line
        true
      else
        false
      end
    end

    def read_bool : Bool
      Bool.new self
    end

    def read_vector : Spatial::Vector
      Spatial::Vector.new self
    end

    private def parse_coordinate_system : Bool
      skip_whitespace
      line = read_line
      case line[0].downcase
      when 'c', 'k' # cartesian
        false
      when 'd' # direct
        true
      else
        parse_exception "Invalid coordinate type"
      end
    end
  end
end
