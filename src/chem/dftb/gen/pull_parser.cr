require "string_scanner"

module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class PullParser < IO::Parser
    include IO::TextPullParser

    @elements = [] of PeriodicTable::Element
    @fractional = false
    @periodic = false

    def initialize(io : ::IO)
      @scanner = StringScanner.new io.to_s
    end

    def each_structure(&block : Structure ->)
      yield parse
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      yield parse if indexes.size == 1 && indexes == 0
    end

    def parse : Structure
      builder = Structure::Builder.new

      n_atoms = read_int
      parse_geometry_type
      parse_elements
      n_atoms.times { builder.atom self }

      builder.lattice self if @periodic
      structure = builder.build
      structure.coords.to_cartesian! if @fractional
      structure
    end

    def parse_element : PeriodicTable::Element
      @elements[read_int - 1]
    rescue IndexError
      parse_exception "Invalid element index"
    end

    private def parse_elements
      read_line.split.each do |symbol|
        @elements << PeriodicTable[symbol]
      end
    end

    private def parse_geometry_type
      skip_whitespace
      case read_char
      when 'F'
        @fractional = @periodic = true
      when 'S'
        @periodic = true
      end
      skip_whitespace
    end
  end
end