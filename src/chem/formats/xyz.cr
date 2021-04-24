@[Chem::FileType(ext: %w(xyz))]
module Chem::XYZ
  class Writer
    include FormatWriter(AtomCollection)
    include MultiFormatWriter(AtomCollection)
    include FormatWriter(Structure)
    include MultiFormatWriter(Structure)

    private def write(atoms : AtomCollection, title : String = "") : Nil
      check_open

      @io.puts atoms.n_atoms
      @io.puts title.gsub(/ *\n */, ' ')
      atoms.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end

    private def write(structure : Structure) : Nil
      write structure, structure.title
    end
  end

  class Reader
    include FormatReader(Structure)
    include MultiFormatReader(Structure)
    include TextFormatReader

    needs guess_topology : Bool = true

    def read_next : Structure?
      check_open
      return if @io.skip_whitespace.eof?
      Structure.build(@guess_topology) do |builder|
        n_atoms = @io.read_int
        @io.skip_line
        builder.title @io.read_line.strip
        n_atoms.times do
          builder.atom PeriodicTable[@io.read_word], @io.read_vector
          @io.skip_line
        end
      end
    end

    def skip : Nil
      check_open
      return if @io.skip_whitespace.eof?
      n_atoms = @io.read_int
      (n_atoms + 2).times { @io.skip_line }
    end
  end
end
