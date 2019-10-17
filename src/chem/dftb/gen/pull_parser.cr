require "string_scanner"

module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class PullParser < IO::Parser
    include IO::PullParser

    @elements = [] of PeriodicTable::Element
    @fractional = false
    @periodic = false

    def each_structure(&block : Structure ->)
      yield parse
    end

    def parse : Structure
      builder = Structure::Builder.new

      n_atoms = read_int
      parse_geometry_type
      parse_elements
      n_atoms.times { builder.atom self }

      builder.lattice self if @periodic
      structure = builder.build
      structure.coords.to_cartesian! if @fractional
      structure
    end

    def parse_element : PeriodicTable::Element
      @elements[read_int - 1]
    rescue IndexError
      parse_exception "Invalid element index"
    end

    private def parse_elements
      loop do
        skip_spaces
        break unless check &.letter?
        @elements << PeriodicTable[scan(&.letter?)]
      end
      skip_line
    end

    private def parse_geometry_type
      skip_spaces
      case read
      when 'F' then @fractional = @periodic = true
      when 'S' then @periodic = true
      when 'C' then @fractional = @periodic = false
      else          parse_exception "Invalid geometry type"
      end
      skip_line
    end
  end
end
