module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class Writer < IO::Writer(AtomCollection)
    def initialize(output : ::IO | Path | String,
                   @fractional : Bool = false,
                   sync_close : Bool = false)
      super output, sync_close
    end

    def write(atoms : AtomCollection, lattice : Lattice? = nil) : Nil
      check_open
      raise Spatial::NotPeriodicError.new if @fractional && lattice.nil?

      ele_table = atoms.each_atom.map(&.element).uniq.with_index.to_h
      geometry_type = @fractional ? 'F' : (lattice ? 'S' : 'C')

      @io.printf "%5d%3s\n", atoms.n_atoms, geometry_type
      ele_table.each_key { |ele| @io.printf "%3s", ele.symbol }
      @io.puts

      atoms.each_atom.with_index do |atom, i|
        ele = ele_table[atom.element] + 1
        vec = atom.coords
        vec = vec.to_fractional lattice.not_nil! if @fractional
        @io.printf "%5d%2s%20.10E%20.10E%20.10E\n", i + 1, ele, vec.x, vec.y, vec.z
      end

      write lattice if lattice
    end

    def write(structure : Structure) : Nil
      write structure, structure.lattice
    end

    private def write(lattice : Lattice) : Nil
      {Spatial::Vector.zero, lattice.i, lattice.j, lattice.k}.each do |vec|
        @io.printf "%20.10E%20.10E%20.10E\n", vec.x, vec.y, vec.z
      end
    end
  end

  @[IO::FileType(format: Gen, ext: [:gen])]
  class Parser < Structure::Parser
    include IO::PullParser

    @elements = [] of Element
    @fractional = false
    @periodic = false

    def next : Structure | Iterator::Stop
      skip_whitespace
      eof? ? stop : parse_next
    end

    def skip_structure : Nil
      @io.skip_to_end
    end

    private def parse_atom(builder : Structure::Builder) : Nil
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

    private def parse_lattice(builder : Structure::Builder) : Nil
      skip_line
      builder.lattice read_vector, read_vector, read_vector
    end

    private def parse_next : Structure
      Structure.build(@guess_topology) do |builder|
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

    private def read_element : Element
      @elements[read_int - 1]
    rescue IndexError
      parse_exception "Invalid element index"
    end
  end
end
