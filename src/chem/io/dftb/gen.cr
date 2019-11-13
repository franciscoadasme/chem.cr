module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class Builder < IO::Builder
    @ele_table = {} of Element => Int32
    @index = 0

    setter atoms = 0
    property? fractional : Bool
    property? periodic = false

    def initialize(@io : ::IO, @fractional : Bool = false)
    end

    def elements=(elements : Enumerable(Element)) : Nil
      @ele_table.clear
      elements.each.uniq.with_index { |ele, i| @ele_table[ele] = i + 1 }
    end

    def element_index(ele : Element) : Int32
      @ele_table[ele]
    end

    def next_index : Int32
      @index += 1
    end

    def object_header : Nil
      reset_index
      number @atoms, width: 5
      string geometry_type, alignment: :right, width: 3
      newline
      @ele_table.each_key &.to_gen(self)
      newline
    end

    private def geometry_type : Char
      if fractional?
        'F'
      elsif periodic?
        'S'
      else
        'C'
      end
    end

    private def reset_index : Nil
      @index = 0
    end
  end

  @[IO::FileType(format: Gen, ext: [:gen])]
  class Parser < IO::Parser
    include IO::PullParser

    @elements = [] of Element
    @fractional = false
    @periodic = false

    def next : Structure | Iterator::Stop
      skip_whitespace
      eof? ? stop : parse
    end

    def skip_structure : Nil
      @io.skip_to_end
    end

    private def parse : Structure
      Structure.build do |builder|
        n_atoms = read_int
        parse_geometry_type
        parse_elements
        n_atoms.times { parse_atom builder }

        parse_lattice builder if @periodic

        @io.skip_to_end # ensure end of file as Gen doesn't support multiple entries

        structure = builder.build
        structure.coords.to_cartesian! if @fractional
      end
    end

    private def parse_atom(builder : Topology::Builder) : Nil
      skip_spaces.skip(&.number?).skip_spaces
      builder.atom read_element, read_vector
      skip_line
    end

    private def parse_elements : Nil
      loop do
        skip_spaces
        break unless check &.letter?
        @elements << PeriodicTable[scan(&.letter?)]
      end
      skip_line
    end

    private def parse_geometry_type : Nil
      skip_spaces
      case read
      when 'F' then @fractional = @periodic = true
      when 'S' then @periodic = true
      when 'C' then @fractional = @periodic = false
      else          parse_exception "Invalid geometry type"
      end
      skip_line
    end

    private def parse_lattice(builder : Topology::Builder) : Nil
      skip_line
      builder.lattice read_vector, read_vector, read_vector
    end

    private def read_element : Element
      @elements[read_int - 1]
    rescue IndexError
      parse_exception "Invalid element index"
    end
  end

  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |gen|
        yield gen
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
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.number gen.next_index, width: 5
      gen.number gen.element_index(@element), width: 2
      gen.convert(coords).to_gen gen
      gen.newline
    end
  end

  module AtomCollection
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.atoms = n_atoms
      gen.elements = each_atom.map(&.element)

      gen.object do
        each_atom &.to_gen(gen)
      end
    end
  end

  class Element
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.string @symbol, alignment: :right, width: 3
    end
  end

  class Lattice
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      {Spatial::Vector.zero, @a, @b, @c}.each do |vec|
        vec.to_gen gen
        gen.newline
      end
    end
  end

  struct Spatial::Vector
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.number @x, precision: 10, scientific: true, width: 20
      gen.number @y, precision: 10, scientific: true, width: 20
      gen.number @z, precision: 10, scientific: true, width: 20
    end
  end

  class Structure
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      raise Spatial::NotPeriodicError.new if gen.fractional? && lattice.nil?

      gen.atoms = n_atoms
      gen.converter = Spatial::Vector::FractionalConverter.new lattice.not_nil! if gen.fractional?
      gen.elements = each_atom.map(&.element)
      gen.periodic = !lattice.nil?

      gen.object do
        each_atom &.to_gen(gen)
        lattice.try &.to_gen(gen)
      end
    end
  end
end
