module Chem::DFTB::Gen
  @[IO::FileType(format: Gen, ext: [:gen])]
  class Builder < IO::Builder
    @ele_table = {} of Element => Int32
    @index = 0

    setter atoms = 0
    property? fractional : Bool
    property? periodic = false

    def initialize(@io : ::IO, @fractional : Bool = false)
    end

    def elements=(elements : Enumerable(Element)) : Nil
      @ele_table.clear
      elements.each.uniq.with_index { |ele, i| @ele_table[ele] = i + 1 }
    end

    def element_index(ele : Element) : Int32
      @ele_table[ele]
    end

    def next_index : Int32
      @index += 1
    end

    def object_header : Nil
      reset_index
      number @atoms, width: 5
      string geometry_type, alignment: :right, width: 3
      newline
      @ele_table.each_key &.to_gen(self)
      newline
    end

    private def geometry_type : Char
      if fractional?
        'F'
      elsif periodic?
        'S'
      else
        'C'
      end
    end

    private def reset_index : Nil
      @index = 0
    end
  end
end
