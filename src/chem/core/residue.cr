module Chem
  class Residue
    include AtomCollection
    include Comparable(Residue)

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
      assign_kind_from_templates
      @chain << self
    end

    # The comparison operator.
    #
    # Returns `-1`, `0` or `1` depending on whether `self` precedes
    # *rhs*, equals to *rhs* or comes after *rhs*. The comparison is
    # done based on chain id, residue number, and insertion code if
    # present.
    #
    # ```
    # residues = Structure.read "peptide.pdb"
    # residues[0] # => <Residue A:TRP1>
    # residues[1] # => <Residue A:GLY1A>
    # residues[2] # => <Residue A:SER1B>
    # residues[3] # => <Residue A:ASN1C>
    # residues[4] # => <Residue A:VAL2>
    # residues[5] # => <Residue B:THR1>
    # residues[6] # => <Residue B:ASN2>
    #
    # residues[0] <=> residues[1] # => -1
    # residues[1] <=> residues[1] # => 0
    # residues[2] <=> residues[1] # => 1
    # residues[0] <=> residues[5] # => -1
    # residues[5] <=> residues[6] # => -1
    # ```
    def <=>(rhs : self) : Int32
      c = chain.id <=> rhs.chain.id
      return c unless c.zero?
      c = number <=> rhs.number
      return c unless c.zero?
      (insertion_code || 'A'.pred) <=> (rhs.insertion_code || 'A'.pred)
    end

    protected def <<(atom : Atom) : self
      @atoms << atom
      @atom_table[atom.name] = atom
      self
    end

    delegate dssp, to: @secondary_structure

    def bonded?(other : self) : Bool
      return false if other.same?(self)
      each_atom.any? do |a1|
        other.each_atom.any? { |a2| a1.bonded? to: a2 }
      end
    end

    def bonded?(other : self, lhs : String, rhs : String) : Bool
      return false if other.same?(self)
      return false unless (a = self[lhs]?) && (b = other[rhs]?)
      a.bonded? b
    end

    def bonded?(other : self, bond_t : Topology::BondType) : Bool
      bonded? other, bond_t.first, bond_t.second
    end

    # Returns bonded residues. Residues may be bonded through any atom.
    #
    # Returned residues are ordered by their chain id, residue number
    # and insertion code if present (refer to #<=>).
    #
    # ```
    # residues = Structure.read("ala-phe-asn-thr.pdb")
    # residues[0].bonded_residues.map(&.name) # => ["PHE"]
    # residues[1].bonded_residues.map(&.name) # => ["ALA", "ASN"]
    # residues[2].bonded_residues.map(&.name) # => ["PHE", "THR"]
    # residues[3].bonded_residues.map(&.name) # => ["ALA", "ASN"]
    # ```
    def bonded_residues : Array(Residue)
      residues = Set(Residue).new
      @atoms.each do |atom|
        atom.each_bonded_atom do |other|
          residues << other.residue unless other.residue == self
        end
      end
      residues.to_a.sort!
    end

    def chain=(new_chain : Chain) : Chain
      @chain.delete self
      @chain = new_chain
      new_chain << self
    end

    def cis? : Bool
      (angle = omega?) ? angle.abs < 30 : false
    end

    def clear : self
      @atom_table.clear
      @atoms.clear
      self
    end

    def delete(atom : Atom) : Atom?
      atom = @atoms.delete atom
      @atom_table.delete atom.name if atom
      atom
    end

    def dig(name : String) : Atom
      self[name]
    end

    def dig?(name : String) : Atom?
      self[name]?
    end

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def each_atom(&block : Atom ->)
      @atoms.each do |atom|
        yield atom
      end
    end

    def has_backbone? : Bool
      !self["N"]?.nil? && !self["CA"]?.nil? && !self["C"]?.nil? && !self["O"]?.nil?
    end

    def hlxparams : Spatial::HlxParams?
      Spatial.hlxparams self
    end

    def inspect(io : ::IO) : Nil
      io << "<Residue "
      to_s io
      io << '>'
    end

    def n_atoms : Int32
      @atoms.size
    end

    def name=(str : String) : String
      @name = str
      assign_kind_from_templates
      str
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

    def polymer? : Bool
      protein? || dna? || !Topology::Templates[name]?.try(&.link_bond).nil?
    end

    def ramachandran_angles : Tuple(Float64, Float64)
      {phi, psi}
    end

    def to_s(io : ::IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
      io << @insertion_code
    end

    def trans? : Bool
      (angle = omega?) ? angle.abs > 150 : false
    end

    {% for member in Kind.constants %}
      def {{member.underscore.id}}? : Bool
        @kind == Kind::{{member}}
      end
    {% end %}

    private def assign_kind_from_templates : Nil
      @kind = Topology::Templates[@name]?.try(&.kind) || Residue::Kind::Other
    end

    # Copies `self` into *chain*
    # It calls `#copy_to` on each atom.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(chain : Chain) : self
      residue = Residue.new @name, @number, @insertion_code, chain
      residue.kind = @kind
      residue.secondary_structure = @secondary_structure
      each_atom &.copy_to(residue)
      residue
    end

    protected def reset_cache : Nil
      @atom_table.clear
      @atoms.sort_by! &.serial
      @atoms.each do |atom|
        @atom_table[atom.name] = atom
      end
    end
  end
end
