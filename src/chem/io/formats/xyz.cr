module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Writer < IO::Writer
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

  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Parser < IO::Parser
    include IO::PullParser

    def next : Structure | Iterator::Stop
      skip_whitespace
      eof? ? stop : parse
    end

    def skip_structure : Nil
      skip_whitespace
      return if eof?
      n_atoms = read_int
      (n_atoms + 2).times { skip_line }
    end

    private def parse : Structure
      Structure.build do |builder|
        n_atoms = read_int
        skip_line
        builder.title read_line.strip
        n_atoms.times { parse_atom builder }
      end
    end

    private def parse_atom(builder : Topology::Builder) : Nil
      skip_whitespace
      builder.atom PeriodicTable[scan(&.letter?)], read_vector
      skip_line
    end
  end
end
