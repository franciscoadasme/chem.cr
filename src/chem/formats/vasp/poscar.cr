@[Chem::RegisterFormat(ext: %w(.poscar), names: %w(POSCAR* CONTCAR*))]
module Chem::VASP::Poscar
  class Writer
    include FormatWriter(Structure)

    def initialize(@io : IO,
                   order @ele_order : Array(Element)? = nil,
                   @fractional : Bool = false,
                   @wrap : Bool = false,
                   @sync_close : Bool = false)
    end

    protected def encode_entry(structure : Structure) : Nil
      raise Spatial::NotPeriodicError.new unless lattice = structure.lattice

      atoms = structure.atoms.to_a.sort_by! &.serial
      coordinate_system = @fractional ? "Direct" : "Cartesian"
      ele_tally = count_elements atoms
      has_constraints = atoms.any? &.constraint

      @io.puts structure.title.gsub(/ *\n */, ' ')
      write lattice
      write_elements ele_tally
      @io.puts "Selective dynamics" if has_constraints
      @io.puts coordinate_system

      ele_tally.each do |ele, _|
        atoms.each.select(&.element.==(ele)).each do |atom|
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

    private def count_elements(atoms : Enumerable(Atom)) : Array(Tuple(Element, Int32))
      ele_tally = atoms.map(&.element).tally.to_a
      if order = @ele_order
        ele_tally.sort_by! do |(k, _)|
          order.index(k) || raise ArgumentError.new "#{k.inspect} not found in specified order"
        end
      end
      ele_tally
    end

    private def write(constraint : Constraint) : Nil
      {:x, :y, :z}.each do |axis|
        @io.printf "%4s", axis.in?(constraint) ? 'F' : 'T'
      end
    end

    private def write(lattice : Lattice) : Nil
      @io.printf " %18.14f\n", 1.0
      {lattice.i, lattice.j, lattice.k}.each do |vec|
        @io.printf " %22.16f%22.16f%22.16f\n", vec.x, vec.y, vec.z
      end
    end

    private def write_elements(ele_table) : Nil
      ele_table.each { |(ele, _)| @io.printf "%5s", ele.symbol.ljust(2) }
      @io.puts
      ele_table.each { |(_, count)| @io.printf "%6d", count }
      @io.puts
    end
  end

  class Reader
    include FormatReader(Structure)

    def initialize(@io : IO, @guess_topology : Bool = true, @sync_close : Bool = false)
      @pull = PullParser.new(@io)
    end

    @builder = uninitialized Structure::Builder
    @constrained = false
    @fractional = false
    @lattice = uninitialized Lattice
    @scale_factor = 1.0
    @species = [] of Element
    @title = ""

    private def read_atom : Atom
      vec = Spatial::Vector.new @pull.next_f, @pull.next_f, @pull.next_f
      vec = @fractional ? vec.to_cartesian(@lattice) : vec * @scale_factor
      atom = @builder.atom @species.shift, vec
      atom.constraint = read_constraint if @constrained
      atom
    end

    private def read_constraint : Constraint?
      case {read_flag, read_flag, read_flag}
      when {true, true, true}    then nil
      when {false, true, true}   then Constraint::X
      when {true, false, true}   then Constraint::Y
      when {true, true, false}   then Constraint::Z
      when {false, false, true}  then Constraint::XY
      when {false, true, false}  then Constraint::XZ
      when {true, false, false}  then Constraint::YZ
      when {false, false, false} then Constraint::XYZ
      else                            @pull.error "Invalid constraint flags"
      end
    end

    private def read_coordinate_system : Nil
      case @pull.char
      when 'C', 'c', 'K', 'k' # cartesian
        @fractional = false
      when 'D', 'd' # direct
        @fractional = true
      else
        @pull.error "Invalid coordinate system"
      end
      @pull.next_line
    end

    private def read_flag : Bool
      @pull.next_token
      case @pull.char
      when 'T' then true
      when 'F' then false
      else          @pull.error "Invalid boolean flag (expected either T or F)"
      end
    end

    private def read_header : Nil
      @title = @pull.line.strip
      @pull.next_line
      @scale_factor = @pull.next_f
      @pull.next_line

      vi = Spatial::Vector.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      vj = Spatial::Vector.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      vk = Spatial::Vector.new @pull.next_f, @pull.next_f, @pull.next_f
      @pull.next_line
      @lattice = Lattice.new vi, vj, vk
      @lattice *= @scale_factor if @scale_factor != 1.0

      read_species

      @pull.next_token
      if @pull.char.in?('s', 'S')
        @constrained = true
        @pull.next_line
        @pull.next_token
      end
      read_coordinate_system
    end

    private def decode_entry : Structure
      raise IO::EOFError.new if @pull.eof?
      read_header
      @builder = Structure::Builder.new guess_topology: @guess_topology
      @builder.title @title
      @builder.lattice @lattice
      @species.size.times do
        read_atom
        @pull.next_line
      end
      @builder.build
    end

    private def read_species : Nil
      elements = [] of Element
      while (str = @pull.next_s?) && str[0].ascii_letter?
        ele = PeriodicTable[str]? || @pull.error("Unknown element")
        elements << ele
      end
      @pull.error("Missing atom species") if elements.empty?

      @pull.next_line
      @species.clear
      elements.map do |ele|
        if count = @pull.next_i?
          count.times { @species << ele }
        else
          @pull.error "Couldn't read number of atoms for #{ele.symbol}"
        end
      end
      @pull.next_line
    end
  end
end
