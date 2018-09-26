require "../../periodic_table"

module Chem::Topology::Templates
  class AtomType
    getter element : PeriodicTable::Element
    getter formal_charge : Int32
    getter name : String
    getter valence : Int32

    def initialize(@name : String,
                   @formal_charge : Int32 = 0,
                   valence : Int32? = nil)
      @element = PeriodicTable.element atom_name: name
      @valence = valence || nominal_valence
    end

    def suffix : String
      name[@element.symbol.size..-1]
    end

    def to_s(io : ::IO)
      io << @name
      io << '(' << @valence << ')' unless @valence == nominal_valence
      io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
      io << @formal_charge.abs if @formal_charge.abs > 1
    end

    private def nominal_valence : Int32
      @element.valence + @formal_charge
    end
  end

  struct Bond
    getter first : String
    getter second : String
    getter order : Int32

    def initialize(@first : String, @second : String, @order : Int = 1)
    end

    def ==(other : Bond) : Bool
      return false if @order != other.order
      return true if @first == other.first && @second == other.second
      @first == other.second && @second == other.first
    end

    def [](index : Int32) : String
      case index
      when 0
        @first
      when 1
        @second
      else
        raise IndexError.new
      end
    end

    def includes?(atom_name : String) : Bool
      @first == atom_name || @second == atom_name
    end

    def includes?(atom_t : AtomType) : Bool
      includes? atom_t.name
    end

    def to_char : Char
      case @order
      when 1 then '-'
      when 2 then '='
      when 3 then '#'
      else        raise "BUG: unreachable"
      end
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
    getter link_bond : Bond?
    getter name : String
    getter symbol : Char?

    def initialize(@name : String,
                   @code : String,
                   @symbol : Char?,
                   @kind : Kind,
                   atom_types : Array(AtomType),
                   bonds : Array(Bond),
                   @link_bond : Bond? = nil)
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

    def monomer? : Bool
      !link_bond.nil?
    end
  end
end
