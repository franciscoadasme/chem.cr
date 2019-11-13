module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class Builder < IO::Builder
    setter atoms = 0
    setter title = ""

    def initialize(@io : ::IO)
    end

    def object_header : Nil
      number @atoms
      newline
      string @title
      newline
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

  def self.build(**options) : String
    String.build do |io|
      build(io, **options) do |xyz|
        yield xyz
      end
    end
  end

  def self.build(io : ::IO, **options) : Nil
    builder = Builder.new io, **options
    builder.document do
      yield builder
    end
  end
end

module Chem
  class Atom
    def to_xyz(xyz : XYZ::Builder) : Nil
      @element.to_xyz xyz
      @coords.to_xyz xyz
      xyz.newline
    end
  end

  module AtomCollection
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.atoms = n_atoms
      xyz.object do
        each_atom &.to_xyz(xyz)
      end
    end
  end

  class Element
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.string symbol, width: 3
    end
  end

  struct Spatial::Vector
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.number x, precision: 5, width: 15
      xyz.number y, precision: 5, width: 15
      xyz.number z, precision: 5, width: 15
    end
  end

  class Structure
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.atoms = n_atoms
      xyz.title = title.gsub(/ *\n */, ' ')

      xyz.object do
        each_atom &.to_xyz(xyz)
      end
    end
  end
end
