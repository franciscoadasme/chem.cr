module Chem::Topology
  class AtomType
    getter element : Element
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

    def inspect(io : ::IO) : Nil
      io << "<AtomType "
      to_s io
      io << '>'
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

  class BondType
    include Indexable(AtomType)

    getter order : Int32
    delegate size, unsafe_fetch, to: @atoms

    @atoms : StaticArray(AtomType, 2)

    def initialize(lhs : AtomType, rhs : AtomType, @order : Int = 1)
      @atoms = StaticArray[lhs, rhs]
    end

    def self.new(lhs : String, rhs : String, order : Int = 1) : self
      BondType.new AtomType.new(lhs), AtomType.new(rhs), order
    end

    def ==(rhs : self) : Bool
      return false if @order != rhs.order
      (self[0] == rhs[0] && self[1] == rhs[1]) ||
        (self[0] == rhs[1] && self[1] == rhs[0])
    end

    def includes?(name : String) : Bool
      any? &.name.==(name)
    end

    def inspect(io : ::IO) : Nil
      io << "<BondType " << self[0].name << to_char << self[1].name << '>'
    end

    def inverse : self
      BondType.new self[1], self[0], @order
    end

    def other(atom_t : AtomType) : AtomType
      case atom_t
      when self[0]
        self[1]
      when self[1]
        self[0]
      else
        raise ArgumentError.new("Cannot find atom type #{atom_t}")
      end
    end

    def other(name : String) : AtomType
      case name
      when self[0].name
        self[1]
      when self[1].name
        self[0]
      else
        raise ArgumentError.new("Cannot find atom type named #{name}")
      end
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

  class ResidueType
    @atom_types : Array(AtomType)
    @bonds : Array(BondType)

    getter name : String
    getter kind : Residue::Kind
    getter link_bond : BondType?
    getter description : String
    getter root : AtomType?
    getter code : Char?

    def initialize(@description : String,
                   @name : String,
                   @code : Char?,
                   @kind : Residue::Kind,
                   atom_types : Array(AtomType),
                   bonds : Array(BondType),
                   @link_bond : BondType? = nil,
                   @root : AtomType? = nil)
      @atom_types = atom_types.dup
      @bonds = bonds.dup
    end

    def self.build(kind : Residue::Kind = :other) : self
      builder = Templates::Builder.new kind
      with builder yield builder
      builder.build
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
      @bonds.select(&.includes?(atom_t)).map &.other(atom_t)
    end

    def bonds : Array(BondType)
      @bonds.dup
    end

    def formal_charge : Int32
      @atom_types.each.map(&.formal_charge).sum
    end

    def inspect(io : ::IO) : Nil
      io << "<ResidueType " << @name
      io << '(' << @code << ')' if @code
      io << ", " << @kind.to_s.downcase unless @kind.other?
      io << '>'
    end

    def monomer? : Bool
      !link_bond.nil?
    end

    def n_atoms : Int32
      @atom_types.size
    end
  end
end
