require "../protein/secondary_structure"

module Chem::PDB
  private struct Record
    @line : String = ""
    @name : String

    getter last_read_range : Range(Int32, Int32) = 0..0

    def initialize(@line : String)
      @name = @line[0..5].rstrip.downcase
    end

    def [](index : Int) : Char
      @last_read_range = index..index
      @line[index]
    end

    def [](range : Range(Int, Int)) : String
      @last_read_range = range
      @line[range]
    end

    def name : String
      @name
    end
  end

  private record SSRecord,
    chain : Char,
    kind : Protein::SecondaryStructure,
    range : Range(Int32, Int32)
end
