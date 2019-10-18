module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Parser < IO::Parser
    include IO::PullParser

    def next : Structure | Iterator::Stop
      skip_whitespace
      eof? ? stop : parse
    end

    def skip_structure
      skip_whitespace
      return if eof?
      n_atoms = read_int
      (n_atoms + 2).times { skip_line }
    end

    private def parse : Structure
      Structure.build do |builder|
        skip_whitespace
        n_atoms = read_int
        skip_line
        builder.title read_line.strip
        n_atoms.times { builder.atom self }
      end
    end
  end
end
