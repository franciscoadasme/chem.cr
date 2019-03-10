module Chem::VASP::Poscar
  class Writer
    @coord_system = CoordinateSystem::Cartesian
    @write_constraint_flags = false

    def initialize(@io : ::IO)
    end

    def <<(structure : Structure) : self
      raise ::IO::Error.new "Cannot overwrite existing content" if @io.pos > 0
      raise ::IO::Error.new "Cannot write a non-periodic structure" unless lattice = structure.lattice

      atoms = structure.each_atom.to_a
      elements = atoms.map &.element
      atoms.sort_by! { |atom| {elements.index(atom.element).as(Int32), atom.serial} }

      @write_constraint_flags = atoms.any? &.constraint

      @io.puts structure.title.gsub(/ *\n */, ' ')
      self << lattice
      self << elements
      @io.puts "Selective dynamics" if @write_constraint_flags
      self << @coord_system
      atoms.each { |atom| self << atom }

      self
    end

    private def <<(atom : Atom)
      @io.printf "%22.16f%22.16f%22.16f", atom.x, atom.y, atom.z
      self << (atom.constraint || Constraint::None) if @write_constraint_flags
      @io.puts
    end

    private def <<(constraint : Constraint)
      {:x, :y, :z}.each do |axis|
        flag = constraint.includes?(axis) ? 'F' : 'T'
        @io.printf "%4s", flag
      end
    end

    private def <<(coord_type : CoordinateSystem)
      case coord_type
      when .cartesian?
        @io.puts "Cartesian"
      when .fractional?
        @io.puts "Direct"
      else
        raise "BUG: unreachable"
      end
    end

    private def <<(elements : Array(PeriodicTable::Element))
      counts = Hash(PeriodicTable::Element, Int32).new 0
      elements.each { |ele| counts[ele] += 1 }

      counts.each_key { |ele| @io.printf "%5s", ele.symbol.ljust 2 }
      @io.puts
      counts.each_value { |count| @io.printf "%6d", count }
      @io.puts
    end

    private def <<(lattice : Lattice)
      @io.printf " %18.14f\n", lattice.scale_factor
      {lattice.a, lattice.b, lattice.c}.each do |vec|
        @io.printf " %22.16f%22.16f%22.16f\n", vec.x, vec.y, vec.z
      end
    end
  end
end
