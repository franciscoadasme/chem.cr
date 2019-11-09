module Chem
  class Atom
    def to_xyz(xyz : XYZ::Builder) : Nil
      @element.to_xyz xyz
      @coords.to_xyz xyz
      xyz.newline
    end
  end

  module AtomCollection
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.atoms = n_atoms
      xyz.object do
        each_atom &.to_xyz(xyz)
      end
    end
  end

  class Element
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.string symbol, width: 3
    end
  end

  struct Spatial::Vector
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.number x, precision: 5, width: 15
      xyz.number y, precision: 5, width: 15
      xyz.number z, precision: 5, width: 15
    end
  end

  class Structure
    def to_xyz(xyz : XYZ::Builder) : Nil
      xyz.atoms = n_atoms
      xyz.title = title.gsub(/ *\n */, ' ')

      xyz.object do
        each_atom &.to_xyz(xyz)
      end
    end
  end
end
