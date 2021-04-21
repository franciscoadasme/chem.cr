module Chem
  class Bond
    enum Kind
      Dative = -1
      Zero   =  0
      Single =  1
      Double =  2
      Triple =  3
    end

    getter first : Atom
    getter second : Atom
    property kind : Kind

    delegate dative?, zero?, single?, double?, triple?, to: @kind

    def initialize(@first, @second, @kind : Kind = :single)
    end

    def initialize(first, second, order : Int32)
      initialize first, second, Kind.from_value(order)
    end

    def [](index : Int32) : Atom
      case index
      when 0 then @first
      when 1 then @second
      else        raise IndexError.new
      end
    end

    def ==(other : self)
      return true if @first == other.first && @second == other.second
      @first == other.second && @second == other.first
    end

    def distance : Float64
      Math.sqrt squared_distance
    end

    def includes?(atom : Atom) : Bool
      @first == atom || @second == atom
    end

    def inspect(io : IO) : Nil
      io << "<Bond "
      @first.to_s io
      io << to_char
      @second.to_s io
      io << '>'
    end

    def order : Int32
      case @kind
      when .dative?
        1
      else
        @kind.to_i
      end
    end

    def order=(order : Int32)
      raise Error.new "Bond order (#{order}) is invalid" if order < 0 || order > 3
      @kind = Kind.from_value order
    end

    def other(atom : Atom) : Atom
      case atom
      when @first
        @second
      when @second
        @first
      else
        raise Error.new "Bond doesn't include atom #{atom.serial}"
      end
    end

    def squared_distance : Float64
      Spatial.squared_distance @first, @second
    end

    def to_char : Char
      case order
      when 0 then '·'
      when 1 then '-'
      when 2 then '='
      when 3 then '#'
      else        raise "BUG: unreachable"
      end
    end
  end
end
