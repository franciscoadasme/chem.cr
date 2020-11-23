module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: %w(gen))]
  class Writer < IO::Writer(AtomCollection)
    def initialize(output : ::IO | Path | String,
                   @fractional : Bool = false,
                   *,
                   sync_close : Bool = false)
      super output, sync_close: sync_close
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

  @[IO::FileType(Structure, format: Gen, ext: %w(gen))]
  class Reader
    include IO::Reader(Structure)

    @builder = uninitialized Structure::Builder
    @elements = [] of Element
    @fractional = false
    @n_atoms = 0
    @periodic = false

    def initialize(io : ::IO,
                   @guess_topology : Bool = true,
                   @sync_close : Bool = false)
      @io = IO::TextIO.new io
    end

    def self.new(path : Path | String, **options) : self
      new File.open(path), **options, sync_close: true
    end

    def read : Structure
      check_open
      check_eof
      parse_header
      @builder = Structure::Builder.new guess_topology: @guess_topology
      @n_atoms.times { read_atom }
      if @periodic
        @io.skip_line
        @builder.lattice @io.read_vector, @io.read_vector, @io.read_vector
      end
      @io.skip_to_end # ensure end of file as Gen doesn't support multiple entries

      structure = @builder.build
      structure.coords.to_cartesian! if @fractional
      structure
    end

    private def parse_coord_type : Nil
      case @io.skip_spaces.read
      when 'F' then @fractional = @periodic = true
      when 'S' then @periodic = true
      when 'C' then @fractional = @periodic = false
      else          parse_exception "Invalid geometry type"
      end
      @io.skip_line
    end

    private def parse_elements : Nil
      @elements.clear
      until @io.eol?
        @elements << PeriodicTable[@io.read_word]
      end
      @io.skip_line
    end

    private def parse_header : Nil
      @n_atoms = @io.read_int
      parse_coord_type
      parse_elements
    end

    private def read_atom : Atom
      @io.skip_spaces.skip_while(&.ascii_number?).skip_spaces
      ele = @elements[@io.read_int - 1]? || parse_exception "Invalid element index"
      vec = @io.read_vector
      @io.skip_line
      @builder.atom ele, vec
    end
  end
end
