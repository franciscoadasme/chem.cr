module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Parser < IO::Parser
    include IO::PullParser

    @elements = [] of PeriodicTable::Element
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

    private def parse_atom(builder : Structure::Builder) : Nil
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

    private def parse_lattice(builder : Structure::Builder) : Nil
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
      rescue ex : ParseException
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
