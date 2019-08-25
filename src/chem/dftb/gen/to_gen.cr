module Chem
  class Atom
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.number gen.next_index, width: 5
      gen.number gen.element_index(@element), width: 2
      gen.convert(coords).to_gen gen
      gen.newline
    end
  end

  module AtomCollection
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.atoms = n_atoms
      gen.elements = each_atom.map(&.element)

      gen.object do
        each_atom &.to_gen(gen)
      end
    end
  end

  class PeriodicTable::Element
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.string @symbol, alignment: :right, width: 3
    end
  end

  class Lattice
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      {Spatial::Vector.zero, @a, @b, @c}.each do |vec|
        vec.to_gen gen
        gen.newline
      end
    end
  end

  struct Spatial::Vector
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      gen.number @x, precision: 10, scientific: true, width: 20
      gen.number @y, precision: 10, scientific: true, width: 20
      gen.number @z, precision: 10, scientific: true, width: 20
    end
  end

  class Structure
    def to_gen(gen : DFTB::Gen::Builder) : Nil
      raise Spatial::NotPeriodicError.new if gen.fractional? && lattice.nil?

      gen.atoms = n_atoms
      gen.converter = Spatial::Vector::FractionalConverter.new lattice.not_nil! if gen.fractional?
      gen.elements = each_atom.map(&.element)
      gen.periodic = !lattice.nil?

      gen.object do
        each_atom &.to_gen(gen)
        lattice.try &.to_gen(gen)
      end
    end
  end
end
