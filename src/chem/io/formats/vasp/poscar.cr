module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: %w(poscar), names: %w(POSCAR* CONTCAR*))]
  class Writer < IO::Writer(AtomCollection)
    def initialize(io : ::IO | Path | String,
                   order @ele_order : Array(Element)? = nil,
                   @fractional : Bool = false,
                   @wrap : Bool = false,
                   *,
                   sync_close : Bool = false)
      super io, sync_close: sync_close
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

  @[IO::FileType(format: Poscar, names: %w(POSCAR* CONTCAR*))]
  class Reader < Structure::Reader
    def next : Structure | Iterator::Stop
      @parser.eof? ? stop : read_next
    end

    def skip_structure : Nil
      @parser.skip_to_end
    end

    private def read_constraint : Constraint?
      cx = @parser.skip_whitespace.read
      cy = @parser.skip_whitespace.read
      cz = @parser.skip_whitespace.read
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

    private def read_coordinate_system : Symbol
      case @parser.skip_whitespace.read.downcase
      when 'c', 'k' # cartesian
        @parser.skip_line
        :cartesian
      when 'd' # direct
        @parser.skip_line
        :fractional
      else
        parse_exception "Couldn't read coordinates type"
      end
    end

    private def read_lattice : Tuple(Lattice, Float64)
      scale_factor = @parser.read_float
      lattice = Lattice.new @parser.read_vector, @parser.read_vector, @parser.read_vector
      {lattice * scale_factor, scale_factor}
    end

    private def read_next : Structure
      title = @parser.read_line.strip
      lattice, scale_factor = read_lattice
      element_counts = read_species
      constrained = @parser.skip_whitespace.check &.in?('s', 'S')
      @parser.skip_line if constrained
      fractional = read_coordinate_system == :fractional

      Structure.build(@guess_topology) do |builder|
        builder.title title
        builder.lattice lattice
        element_counts.each do |ele, count|
          count.times do
            vec = @parser.read_vector
            vec = fractional ? vec.to_cartesian(lattice) : vec * scale_factor
            atom = builder.atom ele, vec
            atom.constraint = read_constraint if constrained
          end
        end
      end
    end

    private def read_species : Array(Tuple(Element, Int32))
      elements = [] of Element
      while @parser.skip_whitespace.check(&.letter?)
        sym = @parser.read_word
        ele = PeriodicTable[sym]? || parse_exception "Unknown element named #{sym}"
        elements << ele
      end
      parse_exception "Couldn't read atom species" if elements.empty?
      elements.map do |ele|
        if count = @parser.read_int?
          {ele, count}
        else
          parse_exception "Couldn't read number of atoms for #{ele.symbol}"
        end
      end
    end
  end
end
