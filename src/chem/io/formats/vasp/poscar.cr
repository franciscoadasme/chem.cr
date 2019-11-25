module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Writer < IO::Writer(AtomCollection)
    def initialize(io : ::IO | Path | String,
                   order @ele_order : Array(Element)? = nil,
                   @fractional : Bool = false,
                   sync_close : Bool = false,
                   @wrap : Bool = false)
      super io, sync_close
    end

    def write(atoms : AtomCollection, lattice : Lattice? = nil, title : String = "") : Nil
      check_open
      raise Spatial::NotPeriodicError.new unless lattice

      coordinate_system = @fractional ? "Direct" : "Cartesian"
      ele_table = count_elements atoms
      has_constraints = atoms.each_atom.any? &.constraint

      @io.puts title.gsub(/ *\n */, ' ')
      write lattice
      write_elements ele_table
      @io.puts "Selective dynamics" if has_constraints
      @io.puts coordinate_system

      ele_table.each_key do |ele|
        atoms.each_atom.select(&.element.==(ele)).each do |atom|
          vec = atom.coords
          if @fractional
            vec = vec.to_fractional lattice
            vec = vec.wrap if @wrap
          elsif @wrap
            vec = vec.wrap lattice
          end

          @io.printf "%22.16f%22.16f%22.16f", vec.x, vec.y, vec.z
          write atom.constraint || Constraint::None if has_constraints
          @io.puts
        end
      end
    end

    def write(structure : Structure) : Nil
      write structure, structure.lattice, structure.title
    end

    private def count_elements(atoms : AtomCollection) : Hash(Element, Int32)
      ele_table = atoms.each_atom.map(&.element).tally
      if ele_order = @ele_order
        if ele = ele_table.keys.find { |ele| !ele_order.includes? ele }
          raise Error.new "Missing #{ele.symbol} in element order"
        end
        ele_table = ele_order.map { |ele| {ele, ele_table[ele]} }.to_h
      end
      ele_table
    end

    private def write(constraint : Constraint) : Nil
      {:x, :y, :z}.each do |axis|
        @io.printf "%4s", constraint.includes?(axis) ? 'F' : 'T'
      end
    end

    private def write(lattice : Lattice) : Nil
      @io.printf " %18.14f\n", 1.0
      {lattice.a, lattice.b, lattice.c}.each do |vec|
        @io.printf " %22.16f%22.16f%22.16f\n", vec.x, vec.y, vec.z
      end
    end

    private def write_elements(ele_table) : Nil
      ele_table.each_key { |ele| @io.printf "%5s", ele.symbol.ljust(2) }
      @io.puts
      ele_table.each_value { |count| @io.printf "%6d", count }
      @io.puts
    end
  end

  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Parser < Structure::Parser
    include IO::PullParser

    @elements = [] of Element
    @fractional = false
    @has_constraints = false
    @scale_factor = 1.0

    def next : Structure | Iterator::Stop
      eof? ? stop : parse_next
    end

    def skip_structure : Nil
      @io.skip_to_end
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

    private def parse_next : Structure
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
end
