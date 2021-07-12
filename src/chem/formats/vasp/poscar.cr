@[Chem::RegisterFormat(ext: %w(.poscar), names: %w(POSCAR* CONTCAR*))]
module Chem::VASP::Poscar
  class Writer < FormatWriter(AtomCollection)
    def initialize(@io : IO,
                   order @ele_order : Array(Element)? = nil,
                   @fractional : Bool = false,
                   @wrap : Bool = false,
                   @sync_close : Bool = false)
    end

    def write(atoms : AtomCollection, lattice : Lattice? = nil, title : String = "") : Nil
      check_open
      raise Spatial::NotPeriodicError.new unless lattice

      atoms = atoms.atoms.to_a.sort_by! &.serial
      coordinate_system = @fractional ? "Direct" : "Cartesian"
      ele_tally = count_elements atoms
      has_constraints = atoms.any? &.constraint

      @io.puts title.gsub(/ *\n */, ' ')
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

    def write(structure : Structure) : Nil
      write structure, structure.lattice, structure.title
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

  class Reader < Structure::Reader
    @builder = uninitialized Structure::Builder
    @constrained = false
    @fractional = false
    @lattice = uninitialized Lattice
    @scale_factor = 1.0
    @species = [] of Element
    @title = ""

    def next : Structure | Iterator::Stop
      @io.eof? ? stop : read_next
    end

    def skip_structure : Nil
      @io.skip_to_end
    end

    private def read_atom : Atom
      vec = @io.read_vector
      vec = @fractional ? vec.to_cartesian(@lattice) : vec * @scale_factor
      atom = @builder.atom @species.shift, vec
      atom.constraint = read_constraint if @constrained
      atom
    end

    private def read_constraint : Constraint?
      cx = @io.skip_whitespace.read
      cy = @io.skip_whitespace.read
      cz = @io.skip_whitespace.read
      case {cx, cy, cz}
      when {'T', 'T', 'T'} then nil
      when {'F', 'T', 'T'} then Constraint::X
      when {'T', 'F', 'T'} then Constraint::Y
      when {'T', 'T', 'F'} then Constraint::Z
      when {'F', 'F', 'T'} then Constraint::XY
      when {'F', 'T', 'F'} then Constraint::XZ
      when {'T', 'F', 'F'} then Constraint::YZ
      when {'F', 'F', 'F'} then Constraint::XYZ
      else
        parse_exception "Couldn't read constraint flags"
      end
    end

    private def read_coordinate_system : Nil
      case @io.skip_whitespace.read.downcase
      when 'c', 'k' # cartesian
        @io.skip_line
        @fractional = false
      when 'd' # direct
        @io.skip_line
        @fractional = true
      else
        parse_exception "Couldn't read coordinates type"
      end
    end

    private def read_header : Nil
      @title = @io.read_line.strip
      @scale_factor = @io.read_float
      @lattice = Lattice.new @io.read_vector, @io.read_vector, @io.read_vector
      @lattice *= @scale_factor if @scale_factor != 1.0
      read_species
      @constrained = @io.skip_whitespace.check &.in?('s', 'S')
      @io.skip_line if @constrained
      read_coordinate_system
    end

    private def read_next : Structure
      read_header
      @builder = Structure::Builder.new guess_topology: @guess_topology
      @builder.title @title
      @builder.lattice @lattice
      @species.size.times { read_atom }
      @builder.build
    end

    private def read_species : Nil
      elements = [] of Element
      while @io.skip_whitespace.check(&.letter?)
        sym = @io.read_word
        ele = PeriodicTable[sym]? || parse_exception "Unknown element named #{sym}"
        elements << ele
      end
      parse_exception "Couldn't read atom species" if elements.empty?
      @species.clear
      elements.map do |ele|
        if count = @io.read_int?
          count.times { @species << ele }
        else
          parse_exception "Couldn't read number of atoms for #{ele.symbol}"
        end
      end
    end
  end
end
