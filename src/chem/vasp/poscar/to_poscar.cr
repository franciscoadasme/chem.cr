module Chem
  class Atom
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.convert(coords).to_poscar poscar
      (constraint || Constraint::None).to_poscar poscar
      poscar.newline
    end
  end

  enum Constraint
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      return unless poscar.constraints?
      {:x, :y, :z}.each do |axis|
        poscar.string includes?(axis) ? 'F' : 'T', alignment: :right, width: 4
      end
    end
  end

  class Lattice
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.space
      poscar.number scale_factor, precision: 14, width: 18
      poscar.newline
      {a, b, c}.each do |vec|
        poscar.space
        vec.to_poscar poscar
        poscar.newline
      end
    end
  end

  class PeriodicTable::Element
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.string symbol.ljust(2), alignment: :right, width: 5
    end
  end

  struct Spatial::Vector
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      poscar.number x, precision: 16, width: 22
      poscar.number y, precision: 16, width: 22
      poscar.number z, precision: 16, width: 22
    end
  end

  class Structure
    def to_poscar(poscar : VASP::Poscar::Builder) : Nil
      raise Spatial::NotPeriodicError.new unless lat = lattice

      poscar.constraints = each_atom.any? &.constraint
      poscar.converter = Spatial::Vector::FractionalConverter.new lat, poscar.wrap? if poscar.fractional?
      poscar.elements = each_atom.map &.element

      poscar.string title.gsub(/ *\n */, ' ')
      poscar.newline
      lattice.try &.to_poscar(poscar)
      poscar.object do
        atoms.to_a
          .sort_by! { |atom| {poscar.element_index(atom.element), atom.serial} }
          .each &.to_poscar(poscar)
      end
    end
  end
end
