module Chem
  class Residue
    include AtomCollection

    enum Kind
      Protein
      DNA
      Ion
      Solvent
      Other
    end

    @atoms = [] of Atom

    property chain : Chain
    property kind : Kind = :other
    property name : String
    property next : Residue?
    property number : Int32
    property previous : Residue?
    property secondary_structure : Protein::SecondaryStructure = :none

    def initialize(@name : String, @number : Int32, @chain : Chain)
    end

    def [](atom_name : String) : Atom
      atoms[atom_name]
    end

    def []?(atom_name : String) : Atom?
      atoms[atom_name]?
    end

    def <<(atom : Atom)
      @atoms << atom
    end

    delegate dssp, to: @secondary_structure

    def bonded?(other : self) : Bool
      each_atom.any? do |a1|
        other.each_atom.any? { |a2| a1.bonded? to: a2 }
      end
    end

    def cis? : Bool
      omega.abs < 30
    end

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def make_atom(**options) : Atom
      options = options.merge({residue: self})
      atom = Atom.new **options
      self << atom
      atom
    end

    def omega : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res.atoms["CA"], prev_res.atoms["C"], atoms["N"],
          atoms["CA"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def phi : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res.atoms["C"], atoms["N"], atoms["CA"], atoms["C"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def psi : Float64
      if (next_res = self.next) && bonded?(next_res)
        Spatial.dihedral atoms["N"], atoms["CA"], atoms["C"], next_res.atoms["N"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def ramachandran_angles : Tuple(Float64, Float64)
      {phi, psi}
    end

    def to_s(io : ::IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
    end

    def trans? : Bool
      omega.abs > 150
    end

    {% for member in Kind.constants %}
      def {{member.underscore.id}}? : Bool
        @kind == Kind::{{member}}
      end
    {% end %}
  end
end
