module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: %w(xyz))]
  class Writer < IO::Writer(AtomCollection)
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
  class Parser < Structure::Reader
    def next : Structure | Iterator::Stop
      @parser.skip_whitespace
      @parser.eof? ? stop : read_next
    end

    private def read_next : Structure
      Structure.build(@guess_topology) do |builder|
        n_atoms = @parser.read_int
        @parser.skip_line
        builder.title @parser.read_line.strip
        n_atoms.times do
          builder.atom PeriodicTable[@parser.read_word], @parser.read_vector
          @parser.skip_line
        end
      end
    end

    def skip_structure : Nil
      @parser.skip_whitespace
      return if @parser.eof?
      n_atoms = @parser.read_int
      (n_atoms + 2).times { @parser.skip_line }
    end
  end
end
