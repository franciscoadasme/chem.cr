module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class Parser < IO::Parser
    include IO::PullParser

    @elements = [] of PeriodicTable::Element
    @fractional = false
    @periodic = false

    def next : Structure | Iterator::Stop
      skip_whitespace
      eof? ? stop : parse
    end

    def parse_element : PeriodicTable::Element
      @elements[read_int - 1]
    rescue IndexError
      parse_exception "Invalid element index"
    end

    private def parse : Structure
      builder = Structure::Builder.new

      n_atoms = read_int
      parse_geometry_type
      parse_elements
      n_atoms.times { builder.atom self }

      builder.lattice self if @periodic

      @io.skip_to_end # ensure end of file as Gen doesn't support multiple entries

      structure = builder.build
      structure.coords.to_cartesian! if @fractional
      structure
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
