@[Chem::RegisterFormat(ext: %w(.gen))]
module Chem::Gen
  class Writer
    include FormatWriter(AtomCollection)

    def initialize(@io : IO,
                   @fractional : Bool = false,
                   @sync_close : Bool = false)
    end

    protected def encode_entry(obj : AtomCollection) : Nil
      lattice = obj.lattice if obj.is_a?(Structure)
      raise Spatial::NotPeriodicError.new if @fractional && lattice.nil?

      ele_table = obj.each_atom.map(&.element).uniq.with_index.to_h
      geometry_type = @fractional ? 'F' : (lattice ? 'S' : 'C')

      @io.printf "%5d%3s\n", obj.n_atoms, geometry_type
      ele_table.each_key { |ele| @io.printf "%3s", ele.symbol }
      @io.puts

      obj.each_atom.with_index do |atom, i|
        ele = ele_table[atom.element] + 1
        vec = atom.coords
        vec = vec.to_fractional lattice.not_nil! if @fractional
        @io.printf "%5d%2s%20.10E%20.10E%20.10E\n", i + 1, ele, vec.x, vec.y, vec.z
      end

      write lattice if lattice
    end

    private def write(lattice : Lattice) : Nil
      {Spatial::Vector.zero, lattice.i, lattice.j, lattice.k}.each do |vec|
        @io.printf "%20.10E%20.10E%20.10E\n", vec.x, vec.y, vec.z
      end
    end
  end

  class Reader
    include FormatReader(Structure)

    @builder = uninitialized Structure::Builder
    @elements = [] of Element
    @fractional = false
    @n_atoms = 0
    @periodic = false

    def initialize(io : IO, @guess_topology : Bool = true, @sync_close : Bool = false)
      @io = TextIO.new io
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

    private def decode_entry : Structure
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
  end
end
