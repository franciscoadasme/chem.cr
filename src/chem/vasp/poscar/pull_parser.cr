require "../../bias"
require "../../periodic_table"
require "../../system"
require "../../spatial/vector"

module Chem::VASP::Poscar
  class PullParser
    include IO::PullParser

    getter element_count = Hash(String, Int32).new { 0 }

    @atom_index = -1
    @coord_system : CoordinateSystem?
    @current_residue = uninitialized Residue
    @elements = [] of PeriodicTable::Element
    @has_constraints : Bool = false
    @lattice : Lattice?

    def atom_count : Int32
      @elements.size
    end

    def current_element : Element
      @elements.first? || fail "There are no more element symbols"
    end

    def current_index : Int32
      @atom_index
    end

    def current_residue : Residue
      @current_residue
    end

    def parse : System
      system = System.new
      chain = system.make_chain identifier: 'A'
      @current_residue = chain.make_residue name: "UNK", number: 1

      system.title = read_line
      system.lattice = read_lattice
      read_elements
      read_selective_dynamics
      read_coord_system

      @elements.size.times do
        @current_residue << read_atom
      end
      system
    end

    def read_atom : Atom
      @atom_index += 1
      @elements.shift if @atom_index > 0
      Atom.new self
    end

    def read_bool : Bool
      Bool.new self
    end

    def read_constraint? : Constraint?
      Constraint.new self if @has_constraints
    end

    # TODO check whether using a tuple and manual math would speed up the parsing
    def read_coords : Spatial::Vector
      coords = read_vector
      case coord_system
      when .cartesian?
        coords * lattice.scale_factor
      when .fractional?
        a = coords.x * lattice.a
        b = coords.y * lattice.b
        c = coords.z * lattice.c
        a + b + c
      else
        raise "BUG: unreachable"
      end
    end

    def read_coord_system : CoordinateSystem
      @coord_system = CoordinateSystem.new self
    end

    def read_elements : Array(PeriodicTable::Element)
      skip_whitespace
      fail "Expected element symbols (vasp 5+)" if peek_char.number?
      elements = scan_multiple(&.letter?).map { |symbol| PeriodicTable[symbol] }
      counts = read_multiple_int
      fail "Mismatch between element symbols and counts" if elements.size != counts.size
      elements.zip(counts) do |ele, count|
        count.times { @elements << ele }
      end
      @elements
    end

    def read_lattice : Lattice
      @lattice = Lattice.new self
    end

    def read_selective_dynamics : Bool
      skip_whitespace
      if peek_char.downcase == 's'
        @has_constraints = true
        skip_line
      end
      @has_constraints
    end

    def read_vector : Spatial::Vector
      Spatial::Vector.new self
    end

    private def coord_system : CoordinateSystem
      if coord_system = @coord_system
        coord_system
      else
        fail "Coordinate type hasn't been read yet"
      end
    end

    private def lattice : Lattice
      if lattice = @lattice
        lattice
      else
        fail "Lattice hasn't been read yet"
      end
    end

    private def parse_exception(msg : String)
      raise ParseException.new msg
    end
  end
end
