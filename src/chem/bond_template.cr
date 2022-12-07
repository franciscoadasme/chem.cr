class Chem::BondTemplate
  getter atoms : {AtomTemplate, AtomTemplate}
  getter order : BondOrder

  delegate double?, single?, triple?, zero?, to: @order

  def initialize(lhs : AtomTemplate, rhs : AtomTemplate, @order : BondOrder = :single)
    @atoms = {lhs, rhs}
  end

  def ==(rhs : self) : Bool
    return false if @order != rhs.order
    @atoms == rhs.atoms || @atoms.reverse == rhs.atoms
  end

  def includes?(atom_t : AtomTemplate) : Bool
    @atoms.includes? atom_t
  end

  def includes?(name : String) : Bool
    @atoms.any? &.name.==(name)
  end

  def other(atom_t : AtomTemplate) : AtomTemplate
    other?(atom_t) || raise KeyError.new("#{atom_t} not found in #{self}")
  end

  def other(name : String) : AtomTemplate
    other?(name) || raise KeyError.new("Atom #{name.inspect} not found in #{self}")
  end

  def other?(atom_t : AtomTemplate) : AtomTemplate?
    case atom_t
    when @atoms[0]
      @atoms[1]
    when @atoms[1]
      @atoms[0]
    end
  end

  def other?(name : String) : AtomTemplate?
    case name
    when @atoms[0].name
      @atoms[1]
    when @atoms[1].name
      @atoms[0]
    end
  end

  def reverse : self
    BondTemplate.new *@atoms.reverse, @order
  end

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::").last}} << ' '
    io << @atoms[0].name << @order.to_char << @atoms[1].name
    io << '>'
  end
end
