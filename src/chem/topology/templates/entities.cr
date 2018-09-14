require "../../periodic_table"

module Chem::Topology::Templates
  class AtomType
    getter element : PeriodicTable::Element
    getter formal_charge : Int32
    getter name : String
    getter? terminal : Bool
    getter valence : Int32

    def initialize(@name : String,
                   @formal_charge : Int32 = 0,
                   valence : Int32? = nil,
                   @terminal : Bool = false)
      @element = PeriodicTable.element atom_name: name
      @valence = valence || nominal_valence
    end

    def suffix : String
      name[@element.symbol.size..-1]
    end

    private def nominal_valence : Int32
      valence = @element.valence + @formal_charge
      valence -= 1 if terminal?
      valence
    end
  end

  struct Bond
    enum Order
      Single   = 1
      Double   = 2
      Triple   = 3
      Aromatic = 4

      def to_char : Char
        case self
        when Single   then '-'
        when Double   then '='
        when Triple   then '#'
        when Aromatic then '@'
        else               raise "BUG: unreachable"
        end
      end
    end

    getter first : AtomType
    getter second : AtomType
    getter order : Order

    def initialize(@first : AtomType, @second : AtomType, @order : Order = :single)
    end

    def ==(other : Bond) : Bool
      return false if @order != other.order
      return true if @first == other.first && @second == other.second
      @first == other.second && @second == other.first
    end

    def includes?(atom_name : String) : Bool
      @first.name == atom_name || @second.name == atom_name
    end

    def includes?(atom_t : AtomType) : Bool
      @first == atom_t || @second == atom_t
    end
  end

  class Residue
    enum Kind
      Protein
      DNA
      Ion
      Solvent
      Other
    end

    @atom_types : Array(AtomType)
    @bonds : Array(Bond)

    getter code : String
    getter kind : Kind
    getter name : String
    getter symbol : Char?

    def initialize(@name : String,
                   @code : String,
                   @symbol : Char?,
                   @kind : Kind,
                   atom_types : Array(AtomType),
                   bonds : Array(Bond))
      @atom_types = atom_types.dup
      @bonds = bonds.dup
    end

    def atom_count(*, include_hydrogens : Bool = true)
      if include_hydrogens
        @atom_types.size
      else
        @atom_types.count &.element.!=(PeriodicTable::Elements::H)
      end
    end

    def atom_names : Array(String)
      @atom_types.map &.name
    end

    def bonds : Array(Bond)
      @bonds.dup
    end

    def formal_charge : Int32
      @atom_types.each.map(&.formal_charge).sum
    end
  end
end
