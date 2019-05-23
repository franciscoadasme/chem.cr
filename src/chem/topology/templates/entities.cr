module Chem::Topology::Templates
  class AtomType
    getter element : PeriodicTable::Element
    getter formal_charge : Int32
    getter name : String
    getter valency : Int32

    def initialize(@name : String,
                   @formal_charge : Int32 = 0,
                   element : String? = nil,
                   valency : Int32? = nil)
      @element = element ? PeriodicTable[element] : PeriodicTable[atom_name: name]
      @valency = valency || nominal_valency
    end

    def suffix : String
      name[@element.symbol.size..]
    end

    def to_s(io : ::IO)
      io << @name
      io << '(' << @valency << ')' unless @valency == nominal_valency
      io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
      io << @formal_charge.abs if @formal_charge.abs > 1
    end

    private def nominal_valency : Int32
      @element.max_valency + @formal_charge
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

    def other(atom_name : String) : String
      @first == atom_name ? @second : @first
    end

    def other(atom_t : AtomType) : String
      other atom_t.name
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
    getter root : AtomType?
    getter symbol : Char?

    def initialize(@name : String,
                   @code : String,
                   @symbol : Char?,
                   @kind : Kind,
                   atom_types : Array(AtomType),
                   bonds : Array(Bond),
                   @link_bond : Bond? = nil,
                   @root : AtomType? = nil)
      @atom_types = atom_types.dup
      @bonds = bonds.dup
    end

    def [](atom_name : String) : AtomType
      self[atom_name]? || raise Error.new "Unknown atom type #{atom_name}"
    end

    def []?(atom_name : String) : AtomType?
      @atom_types.find &.name.==(atom_name)
    end

    def atom_count(*, include_hydrogens : Bool = true)
      size = @atom_types.size
      size -= @atom_types.count &.element.hydrogen? unless include_hydrogens
      size
    end

    def atom_names : Array(String)
      @atom_types.map &.name
    end

    def atom_types : Array(AtomType)
      @atom_types.dup
    end

    def each_atom_type(&block : AtomType ->)
      @atom_types.each &block
    end

    def bonded_atoms(atom_t : AtomType) : Array(AtomType)
      @bonds.select(&.includes?(atom_t)).map { |bond| self[bond.other(atom_t)] }
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

    def n_atoms : Int32
      @atom_types.size
    end
  end
end
