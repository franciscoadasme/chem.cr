class Chem::Templates::Bond
  getter atoms : {Atom, Atom}
  getter order : BondOrder

  delegate double?, single?, triple?, zero?, to: @order

  def initialize(lhs : Atom, rhs : Atom, @order : BondOrder = :single)
    @atoms = {lhs, rhs}
  end

  def ==(rhs : self) : Bool
    return false if @order != rhs.order
    @atoms == rhs.atoms || @atoms.reverse == rhs.atoms
  end

  def includes?(atom_t : Atom) : Bool
    @atoms.includes? atom_t
  end

  def includes?(name : String) : Bool
    @atoms.any? &.name.==(name)
  end

  def other(atom_t : Atom) : Atom
    other?(atom_t) || raise KeyError.new("#{atom_t} not found in #{self}")
  end

  def other(name : String) : Atom
    other?(name) || raise KeyError.new("Atom #{name.inspect} not found in #{self}")
  end

  def other?(atom_t : Atom) : Atom?
    case atom_t
    when @atoms[0]
      @atoms[1]
    when @atoms[1]
      @atoms[0]
    end
  end

  def other?(name : String) : Atom?
    case name
    when @atoms[0].name
      @atoms[1]
    when @atoms[1].name
      @atoms[0]
    end
  end

  def reverse : self
    self.class.new *@atoms.reverse, @order
  end

  def to_s(io : IO) : Nil
    io << '<' << {{@type.name.split("::")[1..].join("::")}} << ' '
    io << @atoms[0].name << @order.to_char << @atoms[1].name
    io << '>'
  end
end
