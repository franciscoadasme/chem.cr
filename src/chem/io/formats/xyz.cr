module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: %w(xyz))]
  class Writer < IO::FormatWriter(AtomCollection)
    def write(atoms : AtomCollection, title : String = "") : Nil
      check_open

      @io.puts atoms.n_atoms
      @io.puts title.gsub(/ *\n */, ' ')
      atoms.each_atom do |atom|
        @io.printf "%-3s%15.5f%15.5f%15.5f\n", atom.element.symbol, atom.x, atom.y, atom.z
      end
    end

    def write(structure : Structure) : Nil
      write structure, structure.title
    end
  end

  @[IO::FileType(format: XYZ, ext: %w(xyz))]
  class Reader < Structure::Reader
    def next : Structure | Iterator::Stop
      @io.skip_whitespace
      @io.eof? ? stop : read_next
    end

    private def read_next : Structure
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

    def skip_structure : Nil
      @io.skip_whitespace
      return if @io.eof?
      n_atoms = @io.read_int
      (n_atoms + 2).times { @io.skip_line }
    end
  end
end
