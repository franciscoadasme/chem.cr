module Chem
  module IO::Converter(T, U)
    abstract def convert(value : T) : U
  end

  class Spatial::Vector::FractionalConverter
    include IO::Converter(Vector, Vector)

    property? wrap : Bool

    def initialize(@lattice : Lattice, @wrap : Bool = false)
    end

    def convert(vec : Vector) : Vector
      vec = vec.to_fractional @lattice
      vec -= vec.map_with_index { |e, i| vec[i] == 1 ? 0 : e.floor } if wrap?
      vec
    end
  end
end
