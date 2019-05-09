module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class PullParser < IO::Parser
    include IO::TextPullParser

    def initialize(io : ::IO)
      @scanner = StringScanner.new io.to_s
    end

    def each_structure(&block : Structure ->)
      until eos?
        yield parse
        skip_whitespace
      end
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      (indexes.max + 1).times do |i|
        if eos?
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
        n_atoms = read_line.to_i
        builder.title read_line
        n_atoms.times { builder.atom self }
      end
    end

    private def skip_structure
      skip_whitespace
      n_atoms = read_line.to_i
      skip_lines n_atoms + 1
    end
  end
end
