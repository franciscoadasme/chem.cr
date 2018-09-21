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

    def initialize(@first, @second, @kind : Kind = :single)
    end

    def ==(other : self)
      return true if @first == other.first && @second == other.second
      @first == other.second && @second == other.first
    end

    def includes?(atom : Atom) : Bool
      @first == atom || @second == atom
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
  end
end