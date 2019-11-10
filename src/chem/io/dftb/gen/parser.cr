module Chem::DFTB::Gen
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
end
