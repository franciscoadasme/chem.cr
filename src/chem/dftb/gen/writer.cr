module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class Writer < IO::Writer
    @serial = 0
    @ele_idxs = uninitialized Hash(String, Int32)
    @transform : Spatial::AffineTransform?

    def initialize(@io : ::IO, @periodic : Bool? = nil, @fractional : Bool = false)
      @periodic = true if @fractional
    end

    def <<(structure : Structure) : self
      raise ::IO::Error.new "Cannot overwrite existing content" if @io.pos > 0
      symbols = structure.each_atom.map(&.element.symbol).uniq.to_a.sort!
      @ele_idxs = symbols.map_with_index { |sym, i| {sym, i + 1} }.to_h

      if lattice = structure.lattice
        @transform = transform? lattice
        write_header structure
        structure.each_atom { |atom| self << atom }
        self << lattice unless @periodic == false
      else
        if @fractional || @periodic
          raise ::IO::Error.new "Cannot write a non-periodic structure"
        end
        write_header structure
        structure.each_atom { |atom| self << atom }
      end
      self
    end

    private def <<(atom : Atom)
      @io.printf "%5d", (@serial += 1)
      @io.printf "%2d", @ele_idxs[atom.element.symbol]
      coords = (transform = @transform) ? transform * atom.coords : atom.coords
      @io.printf "%20.10E%20.10E%20.10E", coords.x, coords.y, coords.z
      @io.puts
    end

    private def <<(lattice : Lattice)
      t = "%20.10E%20.10E%20.10E\n"
      @io.printf t, 0, 0, 0
      @io.printf t, lattice.a.x, lattice.a.y, lattice.a.z
      @io.printf t, lattice.b.x, lattice.b.y, lattice.b.z
      @io.printf t, lattice.c.x, lattice.c.y, lattice.c.z
    end

    private def transform?(lattice : Lattice) : Spatial::AffineTransform?
      if @fractional
        Spatial::AffineTransform.cart_to_fractional lattice
      else
        nil
      end
    end

    private def write_geometry_type(structure : Structure)
      geo_t = if @fractional
                'F'
              elsif @periodic
                'S'
              elsif @periodic.nil?
                structure.lattice ? 'S' : 'C'
              else
                'C'
              end
      @io.printf "%3s", geo_t
    end

    private def write_header(structure : Structure)
      @io.printf "%5d", structure.n_atoms
      write_geometry_type structure
      @io.puts
      @ele_idxs.each_key { |ele| @io.printf "%3s", ele }
      @io.puts
    end
  end
end
