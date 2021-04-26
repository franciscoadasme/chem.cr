# The Poscar module provides capabilities for reading and writing in the
# [VASP](https://www.vasp.at/)'s Poscar file format.
#
# The Poscar file format is a plain text format that encodes a periodic
# molecular structure, e.g., a molecular crystal. It stores atomic
# coordinates, unit cell information, velocities and predictor-corrector
# coordinates for a molecular dynamics simulation. Further details can
# be found at the [Poscar file format
# specification](https://www.vasp.at/wiki/index.php/POSCAR) webpage.
#
# The Poscar file format encodes one `Structure` instance. The following
# information is read from/write to a Poscar file:
#
# * Atomic coordinates
# * Atom constraints
# * Unit cell
#
# Files starting with `POSCAR` and `CONTCAR` or with the file extension
# `.poscar` are recognized as Poscar files.
#
# ### Reading Poscar files
#
# The `Poscar::Reader` class reads an entry from an `IO` or file via the
# `#read` method.
#
# ```
# Poscar::Reader.open("/path/to/poscar") do |reader|
#   reader.read Structure
# end
# ```
#
# Alternatively, use the convenience `Structure.from_poscar` to read the
# structure in a Poscar file.
#
# ```
# Structure.from_poscar "/path/to/poscar" # => <Structure ...>
# ```
#
# Similarly, the general `Structure#read` method can be used to read a
# Poscar file, but the file format is determined on runtime.
#
# ### Writing Poscar files
#
# The `Poscar::Writer` class writes a `Structure` instance to an `IO` or
# file using the `#write` method (note that it raises on multiple
# calls). Alternatively, use the convenience `Structure#to_poscar`
# and `Structure#write` methods.
#
# ```
# Poscar::Writer.open("/path/to/poscar") do |writer|
#   writer.write structure
# end
# # or
# structure.to_poscar "/path/to/poscar"
# # or
# structure.write "/path/to/poscar"
# ```
@[Chem::FileType(ext: %w(poscar), names: %w(POSCAR* CONTCAR*))]
module Chem::VASP::Poscar
  # Writes an entry to a Poscar file.
  #
  # The current implementation conforms to VASP 5.x, where atomic
  # species are written to the Poscar file. The scale factor is always
  # set to 1. The order of the elements can be controlled by the `order`
  # argument when creating a writer, otherwise is guessed from the atom
  # order.
  #
  # ```
  # Poscar::Writer.open("/path/to/poscar") do |writer|
  #   writer.write structure
  # end
  # ```
  class Writer
    include FormatWriter(AtomCollection)
    include FormatWriter(Structure)

    # Order in which elements are to be written. If `nil`, elements are
    # written in the order they appear in the structure.
    needs order : Array(Element)?
    # If `true`, write reduced coordinates, else Cartesian coordinates.
    needs fractional : Bool = false
    # If `true`, wrap coordinates within the primary unit cell before
    # writing them.
    needs wrap : Bool = false

    # Writes *atoms* to the IO encoded in the Poscar file format using
    # *lattice*. If given, *title* will be written as the comment in the
    # header.
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

    # Writes *structure* to the IO. Raises `NotPeriodicError` when
    # *structure* is not periodic (`structure.lattice` returns `nil`.)
    def write(structure : Structure) : Nil
      write structure, structure.lattice, structure.title
    end

    private def count_elements(atoms : Enumerable(Atom)) : Array(Tuple(Element, Int32))
      ele_tally = atoms.map(&.element).tally.to_a
      if ele_order = @order
        ele_tally.sort_by! do |(k, _)|
          ele_order.index(k) || raise ArgumentError.new "#{k.inspect} not found in specified order"
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

  # Reads the entry in a Poscar file. Use the `#read` method to get a
  # `Structure` instance.
  #
  # The current implementation conforms to VASP 5.x, where atomic
  # species are expected to be present in the Poscar file. If missing
  # (VASP 4.x and earlier), an error will be raised.
  #
  # Reduced (fractional) coordinates are transformed to Cartesian
  # coordinates. Lattice parameters and atom coordinates are scaled
  # using the scale factor.
  #
  # ```
  # Poscar::Reader.open("/path/to/poscar") do |reader|
  #   reader.read Structure
  # end
  # ```
  class Reader
    include FormatReader(Structure)
    include TextFormatReader

    # Triggers bond and topology perception after reading. See
    # `Structure::Builder#build` for more information.
    needs guess_topology : Bool = true

    @builder = uninitialized Structure::Builder
    @constrained = false
    @fractional = false
    @lattice = uninitialized Lattice
    @scale_factor = 1.0
    @species = [] of Element
    @title = ""

    def read(type : Structure.class) : Structure
      check_open
      check_eof skip_lines: false
      read_header
      @builder = Structure::Builder.new guess_topology: @guess_topology
      @builder.title @title
      @builder.lattice @lattice
      @species.size.times { read_atom }
      @builder.build
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
