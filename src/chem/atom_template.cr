class Chem::AtomTemplate
  getter element : Element
  getter formal_charge : Int32
  getter name : String
  getter top_spec : String
  getter valence : Int32?

  def initialize(@name : String,
                 @element : Element,
                 @bonded_elements : Array(Element),
                 @formal_charge : Int32 = 0,
                 valence : Int32? = nil)
    @bonded_elements.sort_by!(&.atomic_number.-)
    @top_spec = String.build do |io|
      io << @element.symbol
      @bonded_elements.join(io) { |ele, io| io << ele.symbol }
    end
    raise ArgumentError.new("Invalid valence #{valence} for #{self}") if valence && valence < 0
    @valence = valence || @element.valence
  end

  def self.new(
    name : String,
    top_spec : String,
    formal_charge : Int32 = 0,
    valence : Int32? = nil
  ) : self
    raise ArgumentError.new("Empty atom topology spec") if top_spec.blank?
    elements = top_spec.scan(/[A-Z][a-z]?/).map { |sym| PeriodicTable[sym[0]] }
    new name, elements[0], elements[1..], formal_charge, valence
  end

  def bonded_elements : Array::View(Element)
    @bonded_elements.view
  end

  def suffix : String?
    name[@element.symbol.size..].presence
  end

  def to_s(io : IO)
    io << '<' << {{@type.name.split("::").last}} << ' ' << @name
    io << (@formal_charge > 0 ? '+' : '-') unless @formal_charge == 0
    io << @formal_charge.abs if @formal_charge.abs > 1
    io << '>'
  end
end
