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

    @atom_table = {} of String => Atom
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

    delegate :[], :[]?, to: @atom_table
    delegate structure, to: @chain

    def initialize(name : String, number : Int32, chain : Chain)
      initialize name, number, nil, chain
    end

    def initialize(@name : String,
                   @number : Int32,
                   @insertion_code : Char?,
                   @chain : Chain)
      @chain << self
    end

    protected def <<(atom : Atom)
      if alt_loc = atom.alt_loc
        if conf.nil? || alt_loc == conf.try(&.id)
          @atoms << atom
          @atom_table[atom.name] ||= atom
        end
        conf = conformations[alt_loc]?
        conf ||= conformations.add name, alt_loc, atom.occupancy
        conf.atoms << atom
      else
        @atoms << atom
        @atom_table[atom.name] ||= atom
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
      (angle = omega?) ? angle.abs < 30 : false
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

    def hlxparam : Tuple(Float64, Float64, Float64)?
      return nil unless protein?
      return nil unless prev_res = previous
      return nil unless next_res = self.next
      return nil unless bonded?(prev_res) && bonded?(next_res)

      v1_CA, v1_C = prev_res["CA"].coords, prev_res["C"].coords
      v2_N, v2_CA, v2_C = self["N"].coords, self["CA"].coords, self["C"].coords
      v3_N, v3_CA = next_res["N"].coords, next_res["CA"].coords

      v1 = v1_C - v1_CA
      v2 = v2_N - v1_CA
      v3 = v1.cross(v2).normalize
      v1 = (v1 + v2).normalize
      w1 = v2_C - v2_CA
      w2 = v3_N - v2_CA
      w3 = w1.cross(w2).normalize
      w1 = (w1 + w2).normalize

      tz = (w1 - v1).cross(w3 - v3).normalize

      com1 = (v1_CA + v1_C + v2_N + v2_CA) / 4
      com2 = (v2_CA + v2_C + v3_N + v3_CA) / 4
      zeta = tz.dot(com2 - com1)
      tz, zeta = -tz, -zeta if zeta < 0

      v1p = (v1 - tz * tz.dot(v1)).normalize
      w1p = (w1 - tz * tz.dot(w1)).normalize
      theta = Math.acos v1p.dot(w1p)

      tzp = v1p.cross(w1p).normalize
      handedness = tz.dot tzp
      handedness = 1 if handedness.abs < 1e-9
      handedness /= handedness.abs
      theta = theta * handedness + Math::PI * (1 - handedness)

      r1 = (v3_CA - v2_CA) - tz * zeta
      radius = r1.magnitude / (2 * Math.sin(0.5 * theta))

      {zeta, theta.degrees, radius}
    end

    def omega : Float64
      omega? || raise Error.new "#{self} is terminal"
    end

    def omega? : Float64?
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res["CA"], prev_res["C"], self["N"], self["CA"]
      else
        nil
      end
    end

    def phi : Float64
      phi? || raise Error.new "#{self} is terminal"
    end

    def phi? : Float64?
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res["C"], self["N"], self["CA"], self["C"]
      else
        nil
      end
    end

    def psi : Float64
      psi? || raise Error.new "#{self} is terminal"
    end

    def psi? : Float64?
      if (next_res = self.next) && bonded?(next_res)
        Spatial.dihedral self["N"], self["CA"], self["C"], next_res["N"]
      else
        nil
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
        @atom_table[atom.name] = atom
      end
      @atoms.select! { |atom| {id, nil}.includes? atom.alt_loc }
      @atom_table.select! { |_, atom| {id, nil}.includes? atom.alt_loc }
    end

    def to_s(io : ::IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
    end

    def trans? : Bool
      (angle = omega?) ? angle.abs > 150 : false
    end

    {% for member in Kind.constants %}
      def {{member.underscore.id}}? : Bool
        @kind == Kind::{{member}}
      end
    {% end %}
  end
end
