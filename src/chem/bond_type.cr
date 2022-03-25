class Chem::BondType
  include Indexable(AtomType)

  getter order : Int32
  delegate size, unsafe_fetch, to: @atoms

  @atoms : StaticArray(AtomType, 2)

  def initialize(lhs : AtomType, rhs : AtomType, @order : Int = 1)
    @atoms = StaticArray[lhs, rhs]
  end

  def ==(rhs : self) : Bool
    return false if @order != rhs.order
    (self[0] == rhs[0] && self[1] == rhs[1]) ||
      (self[0] == rhs[1] && self[1] == rhs[0])
  end

  def double? : Bool
    @order == 2
  end

  def includes?(name : String) : Bool
    any? &.name.==(name)
  end

  def includes?(atom_type : AtomType) : Bool
    any? &.name.==(atom_type.name)
  end

  def inspect(io : IO) : Nil
    io << "<BondType "
    to_s io
    io << '>'
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

  def single? : Bool
    @order == 1
  end

  def to_s(io : IO) : Nil
    bond_char = case @order
                when 1 then '-'
                when 2 then '='
                when 3 then '#'
                else        raise "BUG: unreachable"
                end
    io << self[0].name << bond_char << self[1].name
  end

  def triple? : Bool
    @order == 3
  end
end
