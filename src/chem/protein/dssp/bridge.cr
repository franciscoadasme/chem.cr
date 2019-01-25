module Chem::Protein::DSSP
  private struct Bridge
    include Comparable(Bridge)

    enum Type
      None
      Parallel
      AntiParallel
    end

    getter i = Deque(Int32).new
    getter index : Int32
    getter j = Deque(Int32).new
    getter kind : Type

    delegate antiparallel?, parallel?, to: @kind

    def initialize(@index : Int32, @kind : Type, i : Int32, j : Int32)
      @i << i
      @j << j
    end

    def <=>(other : self) : Int32
      i.first <=> other.i.first
    end

    def merge!(other : self)
      @i.concat other.i
      if parallel?
        @j.concat other.j
      else
        other.j.reverse_each { |k| @j.unshift k }
      end
    end

    def to_s(io : ::IO)
      io << @index << ':' << (parallel? ? 'p' : 'a') << ":[" << @i.size << ":"
      @i.join ',', io
      io << '/' << @j.size << ":"
      @j.join ',', io
      io << ']'
    end
  end
end
