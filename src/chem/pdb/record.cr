module Chem::PDB
  private struct Record
    @line : String
    @line_number : Int32

    getter cursor : Range(Int32, Int32) = 0..0
    getter name : String

    def initialize(@line : String, @line_number : Int32)
      @line = @line.ljust 80
      @name = @line[0, 6].delete(' ').downcase
    end

    def [](index : Int) : Char
      @line.to_unsafe[index].unsafe_chr
    end

    def [](range : Range(Int, Int)) : String
      count = range.end - range.begin + 1
      String.new @line.unsafe_byte_slice(range.begin, count)
    end

    def []?(index : Int) : Char?
      char = self[index]
      char.whitespace? ? nil : char
    end

    def []?(range : Range(Int, Int)) : String?
      str = self[range]
      str.blank? ? nil : str
    end
  end
end
