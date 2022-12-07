class Chem::AtomTemplate
  getter element : Element
  getter formal_charge : Int32
  getter name : String
  getter valence : Int32?

  def initialize(@name : String,
                 element : Element | String,
                 valence : Int32? = nil,
                 @formal_charge : Int32 = 0)
    raise ArgumentError.new("Invalid valence") if valence && valence < 0
    @element = element.is_a?(Element) ? element : PeriodicTable[element]
    @valence = valence || @element.valence
  end

  def suffix : String
    name[@element.symbol.size..]
  end

  def to_s(io : IO)
    io << '<' << {{@type.name.split("::").last}} << ' ' << @name
    io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
    io << @formal_charge.abs if @formal_charge.abs > 1
    io << '>'
  end
end
