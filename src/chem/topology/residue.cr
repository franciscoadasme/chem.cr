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

    protected def <<(atom : Atom) : self
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
        @atom_table[atom.name] = atom
      end
      self
    end

    delegate dssp, to: @secondary_structure

    def bonded?(other : self) : Bool
      each_atom.any? do |a1|
        other.each_atom.any? { |a2| a1.bonded? to: a2 }
      end
    end

    def chain=(new_chain : Chain) : Chain
      @chain.delete self
      @chain = new_chain
      new_chain << self
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

    def delete(atom : Atom) : Atom?
      atom = @atoms.delete atom
      @atom_table.delete atom.name if atom
      atom
    end

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def each_atom(&block : Atom ->)
      @atoms.each do |atom|
        yield atom
      end
    end

    def has_alternate_conformations? : Bool
      conformations.any?
    end

    def has_backbone? : Bool
      !self["N"]?.nil? && !self["CA"]?.nil? && !self["C"]?.nil? && !self["O"]?.nil?
    end

    def hlxparams : Spatial::HlxParams?
      Spatial.hlxparams self
    end

    def n_atoms : Int32
      @atoms.size
    end

    def omega : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res["CA"], prev_res["C"], self["N"], self["CA"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def omega? : Float64?
      return nil unless prev_res = self.previous
      return nil unless bonded? prev_res
      return nil unless ca1 = prev_res["CA"]?
      return nil unless c = prev_res["C"]?
      return nil unless n = self["N"]?
      return nil unless ca2 = self["CA"]?
      Spatial.dihedral ca1, c, n, ca2
    end

    def phi : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res["C"], self["N"], self["CA"], self["C"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def phi? : Float64?
      return nil unless prev_res = previous
      return nil unless bonded? prev_res
      return nil unless ca1 = prev_res["C"]?
      return nil unless n = self["N"]?
      return nil unless ca2 = self["CA"]?
      return nil unless c = self["C"]?
      Spatial.dihedral ca1, n, ca2, c
    end

    def psi : Float64
      if (next_res = self.next) && bonded?(next_res)
        Spatial.dihedral self["N"], self["CA"], self["C"], next_res["N"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def psi? : Float64?
      return nil unless next_res = self.next
      return nil unless bonded? next_res
      return nil unless n1 = self["N"]?
      return nil unless ca = self["CA"]?
      return nil unless c = self["C"]?
      return nil unless n2 = next_res["N"]?
      Spatial.dihedral n1, ca, c, n2
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

    protected def reset_cache : Nil
      @atom_table.clear
      @atoms.sort_by! &.serial
      @atoms.each do |atom|
        @atom_table[atom.name] = atom
      end
    end
  end
end
