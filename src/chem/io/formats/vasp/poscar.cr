module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Builder < IO::Builder
    property? constraints = false
    property? fractional : Bool
    setter order : Array(Element)
    property? wrap : Bool
    setter title = ""

    def initialize(@io : ::IO,
                   @order : Array(Element) = [] of Element,
                   @fractional : Bool = false,
                   @wrap : Bool = false)
      @ele_table = Hash(Element, Int32).new default_value: 0
    end

    def element_index(ele : Element) : Int32
      index = @order.index ele
      raise Error.new "Missing #{ele.symbol} in element order" unless index
      index
    end

    def elements=(elements : Enumerable(Element)) : Nil
      @ele_table.clear
      elements.each { |ele| @ele_table[ele] += 1 }
      @order = @ele_table.each_key.uniq.to_a if @order.empty?
    end

    def object_header : Nil
      @order.each &.to_poscar(self)
      newline
      @order.each { |ele| number @ele_table[ele], width: 6 }
      newline
      if constraints?
        string "Selective dynamics"
        newline
      end
      string coordinate_system
      newline
    end

    private def coordinate_system : String
      fractional? ? "Direct" : "Cartesian"
    end
  end

  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Parser < IO::Parser
    include IO::PullParser

    @elements = [] of Element
    @fractional = false
    @has_constraints = false
    @scale_factor = 1.0

    def next : Structure | Iterator::Stop
      eof? ? stop : parse
    end

    def skip_structure : Nil
      @io.skip_to_end
    end

    private def parse : Structure
      Structure.build do |builder|
        builder.title read_line

        @scale_factor = read_float
        skip_line
        parse_lattice builder
        parse_elements
        parse_selective_dynamics
        parse_coordinate_system

        @elements.size.times { parse_atom builder }

        @io.skip_to_end # ensure end of file as POSCAR doesn't support multiple entries
      end
    end

    private def parse_atom(builder : Topology::Builder) : Nil
      vec = read_vector
      vec = @fractional ? vec.to_cartesian(builder.lattice!) : vec * @scale_factor
      atom = builder.atom @elements.shift, vec
      atom.constraint = read_constraint if @has_constraints
    end

    private def parse_coordinate_system : Nil
      skip_whitespace
      line = read_line
      case line[0].downcase
      when 'c', 'k' # cartesian
        @fractional = false
      when 'd' # direct
        @fractional = true
      else
        parse_exception "Invalid coordinate type (expected either Cartesian or Direct)"
      end
    end

    private def parse_elements : Nil
      skip_whitespace
      parse_exception "Expected element symbols (vasp 5+)" if check &.number?
      elements = scan_delimited(&.letter?).map { |symbol| PeriodicTable[symbol] }
      counts = read_atom_counts elements.size
      elements.zip(counts) do |ele, count|
        count.times { @elements << ele }
      end
      skip_line
    end

    private def parse_lattice(builder : Topology::Builder) : Nil
      builder.lattice \
        @scale_factor * read_vector,
        @scale_factor * read_vector,
        @scale_factor * read_vector
    end

    private def parse_selective_dynamics : Nil
      skip_whitespace
      @has_constraints = if check_in_set "sS"
                           skip_line
                           true
                         else
                           false
                         end
    end

    private def read_atom_counts(n : Int) : Array(Int32)
      Array(Int32).new(n) do |i|
        read_int
      rescue ex : IO::ParseException
        ex.message = "Expected #{n - i} more number(s) of atoms per atomic species"
        raise ex
      end
    end

    private def read_bool : Bool
      skip_whitespace
      case flag = read
      when 'F' then false
      when 'T' then true
      else          parse_exception "Invalid boolean flag (expected either T or F)"
      end
    end

    private def read_constraint : Constraint?
      case {read_bool, read_bool, read_bool}
      when {true, true, true}    then nil
      when {false, true, true}   then Constraint::X
      when {true, false, true}   then Constraint::Y
      when {true, true, false}   then Constraint::Z
      when {false, false, true}  then Constraint::XY
      when {false, true, false}  then Constraint::XZ
      when {true, false, false}  then Constraint::YZ
      when {false, false, false} then Constraint::XYZ
      else                            raise "BUG: unreachable"
      end
    end
  end

  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |poscar|
        yield poscar
      end
    end
  end

  def self.build(io : ::IO, **options) : Nil
    builder = Builder.new io, **options
    builder.document do
      yield builder
    end
  end
end

module Chem
  class Atom
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.convert(coords).to_poscar poscar
      (constraint || Constraint::None).to_poscar poscar
      poscar.newline
    end
  end

  enum Constraint
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      return unless poscar.constraints?
      {:x, :y, :z}.each do |axis|
        poscar.string includes?(axis) ? 'F' : 'T', alignment: :right, width: 4
      end
    end
  end

  class Lattice
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.space
      poscar.number 1.0, precision: 14, width: 18
      poscar.newline
      {a, b, c}.each do |vec|
        poscar.space
        vec.to_poscar poscar
        poscar.newline
      end
    end
  end

  class Element
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.string symbol.ljust(2), alignment: :right, width: 5
    end
  end

  struct Spatial::Vector
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.number x, precision: 16, width: 22
      poscar.number y, precision: 16, width: 22
      poscar.number z, precision: 16, width: 22
    end
  end

  class Structure
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      raise Spatial::NotPeriodicError.new unless lat = lattice

      poscar.constraints = each_atom.any? &.constraint
      poscar.converter = Spatial::Vector::FractionalConverter.new lat, poscar.wrap? if poscar.fractional?
      poscar.elements = each_atom.map &.element

      poscar.string title.gsub(/ *\n */, ' ')
      poscar.newline
      lattice.try &.to_poscar(poscar)
      poscar.object do
        atoms.to_a
          .sort_by! { |atom| {poscar.element_index(atom.element), atom.serial} }
          .each &.to_poscar(poscar)
      end
    end
  end
end
