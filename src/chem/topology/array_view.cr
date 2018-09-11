module Chem
  module ArrayView(T)
    include Indexable(T)

    @items : Array(T)

    def initialize(@items)
    end

    delegate find, size, unsafe_at, to: @items

    def [](range : Range(Int, Int)) : self
      {{@type}}.new @items[range]
    end

    def [](start : Int, count : Int) : self
      {{@type}}.new @items[start, count]
    end

    def sort_by(&block : T -> _) : self
      {{@type}}.new @items.sort_by(&block)
    end

    def to_a : Array(T)
      @items.dup
    end
  end
end
