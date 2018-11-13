module Chem::VASP::Poscar
  class Writer
    def initialize(@io : ::IO)
    end

    def write(structure : Structure) : Nil
      raise "cannot write a Poscar without lattice" unless structure.lattice
      atoms = structure.atoms.sort_by { |atom| {atom.element.symbol, atom.serial} }

      @io.puts structure.title.gsub('\n', ' ')
      write structure.lattice.not_nil!
      write_atom_info atoms
      write CoordinateSystem::Cartesian
      atoms.each { |atom| write atom }
    end

    private def write(atom : Atom) : Nil
      write atom.coords
    end

    private def write(coord_type : CoordinateSystem) : Nil
      case coord_type
      when .cartesian?
        @io.puts "Cartesian"
      when .fractional?
        @io.puts "Direct"
      else
        raise "BUG: unreachable"
      end
    end

    private def write(lattice : Lattice) : Nil
      @io.printf "%.8f\n", lattice.scale_factor
      write lattice.a
      write lattice.b
      write lattice.c
    end

    private def write(vector : Spatial::Vector) : Nil
      @io.printf "%14.8f", vector.x
      @io.printf "%14.8f", vector.y
      @io.printf "%14.8f", vector.z
      @io << "\n"
    end

    private def write_atom_info(atoms : AtomView) : Nil
      write_element_symbols atoms
      write_element_counts atoms
    end

    private def write_element_counts(atoms : AtomView) : Nil
      atoms.chunks(&.element).each { |_, values| @io.printf "%-6i", values.size }
      @io << "\n"
    end

    private def write_element_symbols(atoms : AtomView) : Nil
      atoms.map(&.element).uniq.each { |ele| @io.printf "%-6s", ele.symbol }
      @io << "\n"
    end
  end
end
