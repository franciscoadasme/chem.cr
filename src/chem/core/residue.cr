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
    property number : Int32
    property sec : Protein::SecondaryStructure = :none

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

    # Returns `true` if this residue is the same as *rhs*, else `false`.
    #
    # NOTE: overrides the equality operator included by `Comparable`,
    # which uses the `<=>` operator thus returning true for two
    # different residues that have the same chain id, number and
    # insertion code.
    def ==(rhs : self) : Bool
      same?(rhs)
    end

    # Returns the atom that matches *atom_t*.
    #
    # Atom must match both atom type's name and element, otherwise it
    # raises `IndexError`.
    #
    # ```
    # residue = Structure.read("peptide.pdb").residues[0]
    # residue[Topology::AtomType("CA")]               # => <Atom A:TRP1:CA(2)
    # residue[Topology::AtomType("CA", element: "N")] # raises IndexError
    # residue[Topology::AtomType("CX")]               # raises IndexError
    # ```
    def [](atom_t : Topology::AtomType) : Atom
      self[atom_t]? || raise IndexError.new "Cannot find atom for atom type: #{atom_t}"
    end

    # Returns the atom that matches *atom_t*.
    #
    # Atom must match both atom type's name and element, otherwise it
    # returns `nil`.
    #
    # ```
    # residue = Structure.read("peptide.pdb").residues[0]
    # residue[Topology::AtomType("CA")]               # => <Atom A:TRP1:CA(2)
    # residue[Topology::AtomType("CA", element: "N")] # => nil
    # residue[Topology::AtomType("CX")]               # => nil
    # ```
    def []?(atom_t : Topology::AtomType) : Atom?
      if atom = self[atom_t.name]?
        atom if atom.match?(atom_t)
      end
    end

    # Returns true if `self` is bonded to *other*, otherwise false.
    # Residues may be bonded by any two atoms.
    #
    # ```
    # # Covalent ligand (JG7) is bonded to CYS sidechain
    # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
    # residues[0].bonded?(residues[1]) # => true
    # residues[1].bonded?(residues[2]) # => true
    # residues[2].bonded?(residues[3]) # => false
    # residues[1].bonded?(residues[3]) # => true
    # ```
    def bonded?(other : self) : Bool
      return false if other.same?(self)
      each_atom.any? do |a1|
        other.each_atom.any? { |a2| a1.bonded? to: a2 }
      end
    end

    # Returns true if `self` is bonded to *other* through *bond_t*,
    # otherwise false.
    #
    # ```
    # # Covalent ligand (JG7) is bonded to CYS sidechain
    # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
    # bond_t = Topology::BondType.new "C", "N"
    # residues[0].bonded?(residues[1], bond_t) # => true
    # residues[1].bonded?(residues[2], bond_t) # => true
    # residues[2].bonded?(residues[3], bond_t) # => false
    # residues[1].bonded?(residues[3], bond_t) # => false
    # ```
    #
    # Bond check follows the directionality of *bond_t*, that is, the
    # left and right atoms are looked up in `self` and *other*,
    # respectively:
    #
    # ```
    # residues[0].bonded?(residues[1], bond_t) # => true
    # residues[1].bonded?(residues[0], bond_t) # => false
    # ```
    #
    # Note that bond order is taken into account, e.g.:
    #
    # ```
    # bond_t = Topology::BondType.new "C", "N", order: 2
    # residues[0].bonded?(residues[1], bond_t) # => false
    # ```
    #
    # If *strict* is false, it uses elements only instead to look for
    # bonded atoms, and bond order is ignored.
    #
    # ```
    # bond_t = Topology::BondType.new "C", "NX", order: 2
    # residues[0].bonded?(residues[1], bond_t)                # => false
    # residues[0].bonded?(residues[1], bond_t, strict: false) # => true
    # ```
    def bonded?(other : self, bond_t : Topology::BondType, strict : Bool = true) : Bool
      bonded?(other, bond_t[0], bond_t[1], bond_t.order) ||
        (!strict && bonded?(other, bond_t[0].element, bond_t[1].element))
    end

    # Returns true if `self` is bonded to *other* through a bond between
    # *lhs* and *rhs*, otherwise false.
    #
    # ```
    # # Covalent ligand (JG7) is bonded to CYS sidechain
    # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
    # ```
    #
    # One can use atom names, atom types or elements:
    #
    # ```
    # a, b = Topology::AtomType.new("C"), Topology::AtomType.new("N")
    # residues[0].bonded? residues[1], "C", "N"            # => true
    # residues[0].bonded? residues[1], a, b                # => true
    # residues[0].bonded? residues[1], a, PeriodicTable::N # => true
    # residues[0].bonded? residues[1], PeriodicTable::C, b # => true
    # residues[1].bonded? residues[2], a, b                # => true
    # residues[1].bonded? residues[3], a, b                # => false
    # residues[2].bonded? residues[3], a, b                # => false
    # ```
    #
    # Note that *lhs* and *rhs* are looked up in `self` and *other*,
    # respectively, i.e., the arguments are not interchangeable:
    #
    # ```
    # residues[0].bonded? residues[1], "C", "N" # => true
    # residues[0].bonded? residues[1], "N", "C" # => false
    # ```
    #
    # When atom names or atom types are specified, this method returns
    # false if missing:
    #
    # ```
    # missing_atom_t = Topology::AtomType.new("OZ5")
    # residues[0].bonded? residues[1], "CX1", "N"             # => false
    # residues[0].bonded? residues[1], missing_atom_t, "N"    # => false
    # residues[0].bonded? residues[1], "C", PeriodicTable::Mg # => false
    # ```
    #
    # When elements are specified, all atoms of that element are tested:
    #
    # ```
    # residues[1].bonded? residues[2], "C", PeriodicTable::N  # => true
    # residues[1].bonded? residues[2], "SG", PeriodicTable::C # => true
    # ```
    #
    # If *order* is specified, it also check for bond order, otherwise
    # it is ignored:
    #
    # ```
    # residues[0].bonded? residues[1], "C", "N"    # => true
    # residues[0].bonded? residues[1], "C", "N", 1 # => true
    # residues[0].bonded? residues[1], "C", "N", 2 # => false
    # ```
    def bonded?(other : self,
                lhs : Topology::AtomType | String,
                rhs : Topology::AtomType | String,
                order : Int? = nil) : Bool
      return false if other.same?(self)
      return false unless (a = self[lhs]?) && (b = other[rhs]?)
      return false unless bond = a.bonds[b]?
      bond.order == (order || bond.order)
    end

    # :ditto:
    def bonded?(other : self,
                lhs : Topology::AtomType | String,
                rhs : Element,
                order : Int? = nil) : Bool
      return false if other.same?(self)
      return false unless a = self[lhs]?
      other.each_atom.any? do |b|
        if b === rhs && (bond = a.bonds[b]?)
          bond.order == (order || bond.order)
        end
      end
    end

    # :ditto:
    def bonded?(other : self,
                lhs : Element,
                rhs : Topology::AtomType | String,
                order : Int? = nil) : Bool
      return false if other.same?(self)
      return false unless b = other[rhs]?
      @atoms.any? do |a|
        if a === lhs && (bond = a.bonds[b]?)
          bond.order == (order || bond.order)
        end
      end
    end

    # :ditto:
    def bonded?(other : self, lhs : Element, rhs : Element, order : Int? = nil) : Bool
      return false if other.same?(self)
      @atoms.any? do |a|
        next unless a === lhs
        other.each_atom.any? do |b|
          if b === rhs && (bond = a.bonds[b]?)
            bond.order == (order || bond.order)
          end
        end
      end
    end

    # Returns bonded residues. Residues may be bonded through any atom.
    #
    # Returned residues are ordered by their chain id, residue number
    # and insertion code if present (refer to #<=>).
    #
    # ```
    # # Covalent ligand (JG7) is bonded to CYS sidechain
    # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
    # residues[0].bonded_residues.map(&.name) # => ["CYS"]
    # residues[1].bonded_residues.map(&.name) # => ["ALA", "THR", "JG7"]
    # residues[2].bonded_residues.map(&.name) # => ["CYS"]
    # residues[3].bonded_residues.map(&.name) # => ["CYS"]
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

    # Returns residues bonded through *bond_t*.
    #
    # Returned residues are ordered by their chain id, residue number
    # and insertion code if present (refer to #<=>).
    #
    # ```
    # # Covalent ligand (JG7) is bonded to CYS sidechain
    # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
    # bond_t = Topology::BondType.new("C", "N")
    # residues[0].bonded_residues(bond_t).map(&.name) # => ["CYS"]
    # residues[1].bonded_residues(bond_t).map(&.name) # => ["THR"]
    # residues[2].bonded_residues(bond_t).map(&.name) # => []
    # residues[3].bonded_residues(bond_t).map(&.name) # => []
    # ```
    #
    # If *forward_only* is false, then bond directionality is ignored:
    #
    # ```
    # residues[0].bonded_residues(bond_t, forward_only: true).map(&.name) # => ["CYS"]
    # residues[1].bonded_residues(bond_t, forward_only: true).map(&.name) # => ["ALA", "THR"]
    # residues[2].bonded_residues(bond_t, forward_only: true).map(&.name) # => ["CYS"]
    # residues[3].bonded_residues(bond_t, forward_only: true).map(&.name) # => []
    # ```
    #
    # If *strict* is false, bond search checks elements only, and bond
    # order is ignored (fuzzy search). In the following example, using
    # `strict: false` makes that any C-N bond is accepted regardless of
    # atom names or bond order:
    #
    # ```
    # bond_t = Topology::BondType.new "C", "NX", order: 2
    # residues[0].bonded_residues(bond_t, strict: false).map(&.name) # => ["CYS"]
    # residues[1].bonded_residues(bond_t, strict: false).map(&.name) # => ["THR"]
    # residues[2].bonded_residues(bond_t, strict: false).map(&.name) # => []
    # residues[3].bonded_residues(bond_t, strict: false).map(&.name) # => []
    # ```
    def bonded_residues(bond_t : Topology::BondType,
                        forward_only : Bool = true,
                        strict : Bool = true) : Array(Residue)
      bonded_residues.select! do |residue|
        bonded = bonded?(residue, bond_t, strict)
        bonded ||= residue.bonded?(self, bond_t, strict) unless forward_only
        bonded
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

    def clear : self
      @atom_table.clear
      @atoms.clear
      self
    end

    def delete(atom : Atom) : Atom?
      atom = @atoms.delete atom
      @atom_table.delete(atom.name) if atom && @atom_table[atom.name]?.same?(atom)
      atom
    end

    # Returns `true` is residue is dextrorotatory, otherwise `false`.
    #
    # A residue is considered to be dextrorotatory if the improper angle
    # C-CA-C-CB is negative.
    #
    # Note that this method returns `false` if the residue doesn't have
    # any of such atoms, therefore it's not always equal to the inverse
    # of `#levo?`.
    def dextro? : Bool
      if (n = self["N"]?) && (ca = self["CA"]?) && (c = self["C"]?) && (cb = self["CB"]?)
        Spatial.improper(n, ca, c, cb) < 0
      else
        false
      end
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
      Spatial.hlxparams self, structure.lattice
    end

    def inspect(io : IO) : Nil
      io << "<Residue "
      to_s io
      io << '>'
    end

    # Returns `true` is residue is levorotatory, otherwise `false`.
    #
    # A residue is considered to be levorotatory if the improper angle
    # C-CA-C-CB is positive.
    #
    # Note that this method returns `false` if the residue doesn't have
    # any of such atoms, therefore it's not always equal to the inverse
    # of `#dextro?`.
    def levo? : Bool
      if (n = self["N"]?) && (ca = self["CA"]?) && (c = self["C"]?) && (cb = self["CB"]?)
        Spatial.improper(n, ca, c, cb) > 0
      else
        false
      end
    end

    def n_atoms : Int32
      @atoms.size
    end

    def name=(str : String) : String
      @name = str
      assign_kind_from_templates
      str
    end

    # Returns the following residue if exists, otherwise `nil`.
    #
    # It uses the link bond type of the associated residue type, if
    # present, to search for the next residue. Thus, link bond
    # determines the direction, e.g., C(i)-N(i+1). Be aware that atom
    # types must match exactly to find a residue unless *strict* is
    # `false`.
    #
    # Otherwise, it returns a bonded residue whose number and insertion
    # code come just after those of `self`. This fallback can be
    # disabled by setting *use_numbering* to `false`.
    #
    # Note that when multiple residues can be connected to the same
    # residue (e.g., branched polymers), it returns the first residue
    # among them.
    def next(strict : Bool = true, use_numbering : Bool = true) : Residue?
      if bond_t = type.try(&.link_bond)
        residues = bonded_residues bond_t
        residues = bonded_residues bond_t, strict: false if residues.empty? && !strict
        residues.sort!.first?
      elsif use_numbering
        bonded_residues.select!(&.>(self)).sort!.first?
      end
    end

    def omega : Float64
      omega? || raise Error.new "#{self} is terminal"
    end

    def omega? : Float64?
      if (ca1 = pred.try(&.[]?("CA"))) &&
         (c = pred.try(&.[]?("C"))) &&
         (n = self["N"]?) &&
         (ca2 = self["CA"]?)
        Spatial.dihedral ca1, c, n, ca2, structure.lattice
      end
    end

    def phi : Float64
      phi? || raise Error.new "#{self} is terminal"
    end

    def phi? : Float64?
      if (ca1 = pred.try(&.[]?("C"))) &&
         (n = self["N"]?) &&
         (ca2 = self["CA"]?) &&
         (c = self["C"]?)
        Spatial.dihedral ca1, n, ca2, c, structure.lattice
      end
    end

    # Returns the preceding residue if exists, otherwise `nil`.
    #
    # It uses the link bond type of the associated residue type, if
    # present, to search for the previous residue. Thus, link bond
    # determines the direction, e.g., C(i-1)-N(i). Be aware that atom
    # types must match exactly to find a residue unless *strict* is
    # `false`.
    #
    # Otherwise, it returns a bonded residue whose number and insertion
    # code come just before those of `self`. This fallback can be
    # disabled by setting *use_numbering* to `false`.
    #
    # Note that when multiple residues can be connected to the same
    # residue (e.g., branched polymers), it returns the last residue
    # among them.
    def pred(strict : Bool = true, use_numbering : Bool = true) : Residue?
      if bond_t = type.try(&.link_bond).try(&.inverse)
        residues = bonded_residues bond_t
        residues = bonded_residues bond_t, strict: false if residues.empty? && !strict
        residues.sort!.last?
      elsif use_numbering
        bonded_residues.select!(&.<(self)).sort!.last?
      end
    end

    def psi : Float64
      psi? || raise Error.new "#{self} is terminal"
    end

    def psi? : Float64?
      if (n1 = self["N"]?) &&
         (ca = self["CA"]?) &&
         (c = self["C"]?) &&
         (n2 = self.next.try(&.[]?("N")))
        Spatial.dihedral n1, ca, c, n2, structure.lattice
      end
    end

    def polymer? : Bool
      !!(protein? || dna? || type.try(&.monomer?))
    end

    def ramachandran_angles : Tuple(Float64, Float64)
      {phi, psi}
    end

    def to_s(io : IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
      io << @insertion_code
    end

    def trans? : Bool
      (angle = omega?) ? angle.abs > 150 : false
    end

    # Returns associated residue type if registered, otherwise nil.
    #
    # The type of a residue is fetched by its name.
    def type : Topology::ResidueType?
      Topology::Templates[@name]?
    end

    {% for member in Kind.constants %}
      def {{member.underscore.id}}? : Bool
        @kind == Kind::{{member}}
      end
    {% end %}

    private def assign_kind_from_templates : Nil
      @kind = type.try(&.kind) || Kind::Other
    end

    # Copies `self` into *chain*
    # It calls `#copy_to` on each atom.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(chain : Chain) : self
      residue = Residue.new @name, @number, @insertion_code, chain
      residue.kind = @kind
      residue.sec = @sec
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
