class Chem::AtomType
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

  def inspect(io : IO) : Nil
    io << "<AtomType "
    to_s io
    io << '>'
  end

  def suffix : String
    name[@element.symbol.size..]
  end

  def to_s(io : IO)
    io << @name
    io << '(' << @valency << ')' unless @valency == nominal_valency
    io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
    io << @formal_charge.abs if @formal_charge.abs > 1
  end

  private def nominal_valency : Int32
    # FIXME: this is completely wrong. N+ and Mg2+ behave differently.
    valency = @element.max_valency
    valency += @element.ionic? ? -@formal_charge.abs : @formal_charge
    valency
  end
end
