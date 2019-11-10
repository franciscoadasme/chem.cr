module Chem::XYZ
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
