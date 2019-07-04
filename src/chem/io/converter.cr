module Chem
  module IO::Converter(T, U)
    abstract def convert(value : T) : U
  end

  class Spatial::Vector::FractionalConverter
    include IO::Converter(Vector, Vector)

    property? wrap : Bool

    def initialize(lattice : Lattice, @wrap : Bool = false)
      @transform = AffineTransform.cart_to_fractional lattice
    end

    def convert(value : Vector) : Vector
      value *= @transform
      value -= value.map_with_index { |e, i| value[i] == 1 ? 0 : e.floor } if wrap?
      value
    end
  end
end
