module Chem::VASP::Poscar
  @[IO::FileType(format: Poscar, ext: [:poscar])]
  class Builder < IO::Builder
    property? constraints = false
    property? fractional : Bool
    setter order : Array(Element)
    property? wrap : Bool
    setter title = ""

    def initialize(@io : ::IO,
                   @order : Array(Element) = [] of Element,
                   @fractional : Bool = false,
                   @wrap : Bool = false)
      @ele_table = Hash(Element, Int32).new default_value: 0
    end

    def element_index(ele : Element) : Int32
      index = @order.index ele
      raise Error.new "Missing #{ele.symbol} in element order" unless index
      index
    end

    def elements=(elements : Enumerable(Element)) : Nil
      @ele_table.clear
      elements.each { |ele| @ele_table[ele] += 1 }
      @order = @ele_table.each_key.uniq.to_a if @order.empty?
    end

    def object_header : Nil
      @order.each &.to_poscar(self)
      newline
      @order.each { |ele| number @ele_table[ele], width: 6 }
      newline
      if constraints?
        string "Selective dynamics"
        newline
      end
      string coordinate_system
      newline
    end

    private def coordinate_system : String
      fractional? ? "Direct" : "Cartesian"
    end
  end
end
