require "./residue/*"

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
    getter conformations : ConformationManager { ConformationManager.new self }
    property insertion_code : Char?
    property kind : Kind = :other
    property name : String
    property next : Residue?
    property number : Int32
    property previous : Residue?
    property secondary_structure : Protein::SecondaryStructure = :none

    delegate system, to: @chain

    def initialize(name : String, number : Int32, chain : Chain)
      initialize name, number, nil, chain
    end

    def initialize(@name : String,
                   @number : Int32,
                   @insertion_code : Char?,
                   @chain : Chain)
      @chain << self
    end

    def [](atom_name : String) : Atom
      atoms[atom_name]
    end

    def []?(atom_name : String) : Atom?
      atoms[atom_name]?
    end

    def <<(atom : Atom)
      raise "Atom #{atom} does not belong to #{self}" unless atom.residue.same? self
      if (other = self[atom.name]?) && atom.alt_loc == other.alt_loc
        raise Chem::Error.new "Duplicate atom #{atom.name} in #{self}"
      end

      if alt_loc = atom.alt_loc
        @atoms << atom if conf.nil? || alt_loc == conf.try(&.id)
        conf = conformations[alt_loc]?
        conf ||= conformations.add name, alt_loc, atom.occupancy
        conf.atoms << atom
      else
        @atoms << atom
      end
      self
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

    def conf : Conformation?
      conformations.current
    end

    def conf=(id : Char)
      conformations.current = id
    end

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def has_alternate_conformations? : Bool
      conformations.any?
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

    protected def swap_conf_atoms(id : Char, atoms : Array(Atom))
      atoms.each do |atom|
        if idx = @atoms.index &.name.==(atom.name)
          @atoms[idx] = atom
        else
          @atoms << atom
        end
      end
      @atoms.select! { |atom| {id, nil}.includes? atom.alt_loc }
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
