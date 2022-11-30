class Chem::BondTemplate
  include Indexable(AtomTemplate)

  getter order : BondOrder

  delegate double?, single?, triple?, zero?, to: @order
  delegate size, unsafe_fetch, to: @atoms

  @atoms : StaticArray(AtomTemplate, 2)

  def initialize(lhs : AtomTemplate, rhs : AtomTemplate, @order : BondOrder = :single)
    @atoms = StaticArray[lhs, rhs]
  end

  def ==(rhs : self) : Bool
    return false if @order != rhs.order
    (self[0] == rhs[0] && self[1] == rhs[1]) ||
      (self[0] == rhs[1] && self[1] == rhs[0])
  end

  def includes?(name : String) : Bool
    any? &.name.==(name)
  end

  def includes?(atom_t : AtomTemplate) : Bool
    any? &.name.==(atom_t.name)
  end

  def inspect(io : IO) : Nil
    io << '<' << {{@type.name.split("::").last}} << ' '
    to_s io
    io << '>'
  end

  def inverse : self
    BondTemplate.new self[1], self[0], @order
  end

  def other(atom_t : AtomTemplate) : AtomTemplate
    case atom_t
    when self[0]
      self[1]
    when self[1]
      self[0]
    else
      raise ArgumentError.new("Cannot find atom template #{atom_t}")
    end
  end

  def other(name : String) : AtomTemplate
    case name
    when self[0].name
      self[1]
    when self[1].name
      self[0]
    else
      raise ArgumentError.new("Cannot find atom template named #{name}")
    end
  end

  def to_s(io : IO) : Nil
    io << self[0].name << @order.to_char << self[1].name
  end
end
