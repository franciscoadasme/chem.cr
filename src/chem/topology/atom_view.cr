require "./atom"

module Chem
  struct AtomView
    include Indexable(Atom)

    # TODO use WeakRef(Atom) or AtomRef < WeakRef(Atom)?
    @atoms : Array(Atom)

    def initialize(@atoms)
    end

    delegate size, unsafe_at, to: @atoms

    def [](range : Range(Int, Int)) : self
      AtomView.new @atoms[range]
    end

    def [](start : Int, count : Int) : self
      AtomView.new @atoms[start, count]
    end

    def sort_by(&block : Atom -> _) : self
      AtomView.new @atoms.sort_by(&block)
    end

    def to_a : Array(Atom)
      @atoms.dup
    end
  end
end
