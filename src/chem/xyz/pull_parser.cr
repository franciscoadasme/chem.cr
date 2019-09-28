module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class PullParser < IO::Parser
    include IO::PullParser

    def initialize(@io : ::IO)
    end

    def each_structure(&block : Structure ->)
      until eof?
        yield parse
        skip_whitespace
      end
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      (indexes.max + 1).times do |i|
        if eof?
          raise IndexError.new
        elsif indexes.includes? i
          yield parse
        else
          skip_structure
        end
      end
    end

    def parse : Structure
      Structure.build do |builder|
        skip_whitespace
        n_atoms = read_int
        skip_line
        builder.title read_line.strip
        n_atoms.times { builder.atom self }
      end
    end

    private def skip_structure
      skip_whitespace
      n_atoms = read_int
      (n_atoms + 2).times { skip_line }
    end
  end
end
