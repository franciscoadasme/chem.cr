enum Chem::ResidueType
  Protein
  DNA
  Ion
  Solvent
  Membrane
  Other
end

class Chem::Residue
  include Comparable(Residue)

  @atom_table = {} of String => Atom
  @atoms = [] of Atom

  property chain : Chain
  property insertion_code : Char?
  property type : ResidueType = :other
  property name : String
  property number : Int32
  property sec : Protein::SecondaryStructure = :none

  # TODO: Remove this delegate. Use #dig methods
  delegate :[], :[]?, to: @atom_table
  delegate structure, to: @chain

  # TODO: Implement `#bonds`
  # TODO: Implement `#formal_charge`

  def initialize(
    @chain : Chain,
    @number : Int32,
    @insertion_code : Char?,
    @name : String
  )
    assign_type_from_templates
    @chain << self
  end

  def self.new(chain : Chain, number : Int32, name : String) : self
    new chain, number, nil, name
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
  def <=>(other : self) : Int32
    c = chain.id <=> other.chain.id
    return c unless c.zero?
    c = number <=> other.number
    return c unless c.zero?
    (insertion_code || 'A'.pred) <=> (other.insertion_code || 'A'.pred)
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
  # Atom must match both atom template's name and element, otherwise
  # it raises `IndexError`.
  #
  # ```
  # residue = Structure.read("peptide.pdb").residues[0]
  # residue[Templates::Atom("CA")]               # => <Atom A:TRP1:CA(2)
  # residue[Templates::Atom("CA", element: "N")] # raises IndexError
  # residue[Templates::Atom("CX")]               # raises IndexError
  # ```
  #
  # TODO: Move to Templates or other namespace
  def [](atom_t : Templates::Atom) : Atom
    self[atom_t]? || raise IndexError.new "Cannot find atom for template: #{atom_t}"
  end

  # Returns the atom that matches *atom_t*.
  #
  # Atom must match both atom template's name and element, otherwise
  # it returns `nil`.
  #
  # ```
  # residue = Structure.read("peptide.pdb").residues[0]
  # residue[Templates::Atom("CA")]               # => <Atom A:TRP1:CA(2)
  # residue[Templates::Atom("CA", element: "N")] # => nil
  # residue[Templates::Atom("CX")]               # => nil
  # ```
  #
  # TODO: Move to Templates or other namespace
  def []?(atom_t : Templates::Atom) : Atom?
    if atom = self[atom_t.name]?
      atom if atom.matches?(atom_t)
    end
  end

  def atoms : AtomView
    AtomView.new @atoms
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
    atoms.any? do |a1|
      other.atoms.any? { |a2| a1.bonded? to: a2 }
    end
  end

  # Returns true if `self` is bonded to *other* through *bond_t*,
  # otherwise false.
  #
  # ```
  # # Covalent ligand (JG7) is bonded to CYS sidechain
  # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
  # bond_t = Templates::Bond.new "C", "N"
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
  # bond_t = Templates::Bond.new "C", "N", order: 2
  # residues[0].bonded?(residues[1], bond_t) # => false
  # ```
  #
  # If *strict* is false, it uses elements only instead to look for
  # bonded atoms, and bond order is ignored.
  #
  # ```
  # bond_t = Templates::Bond.new "C", "NX", order: 2
  # residues[0].bonded?(residues[1], bond_t)                # => false
  # residues[0].bonded?(residues[1], bond_t, strict: false) # => true
  # ```
  def bonded?(other : self, bond_t : Templates::Bond, strict : Bool = true) : Bool
    bonded?(other, *bond_t.atoms, bond_t.order) ||
      (!strict && bonded?(other, *bond_t.atoms.map(&.element)))
  end

  # Returns true if `self` is bonded to *other* through a bond between
  # *lhs* and *rhs*, otherwise false.
  #
  # ```
  # # Covalent ligand (JG7) is bonded to CYS sidechain
  # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
  # ```
  #
  # One can use atom names, atom template, or elements:
  #
  # ```
  # a, b = Templates::Atom.new("C"), Templates::Atom.new("N")
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
  # When atom names or atom template are specified, this method
  # returns false if missing:
  #
  # ```
  # missing_atom_t = Templates::Atom.new("OZ5")
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
              lhs : Templates::Atom | String,
              rhs : Templates::Atom | String,
              order : BondOrder? = nil) : Bool
    return false if other.same?(self)
    return false unless (a = self[lhs]?) && (b = other[rhs]?)
    return false unless bond = a.bonds[b]?
    bond.order == (order || bond.order)
  end

  # :ditto:
  def bonded?(other : self,
              lhs : Templates::Atom | String,
              rhs : Element,
              order : BondOrder? = nil) : Bool
    return false if other.same?(self)
    return false unless a = self[lhs]?
    other.atoms.any? do |b|
      if b === rhs && (bond = a.bonds[b]?)
        bond.order == (order || bond.order)
      end
    end
  end

  # :ditto:
  def bonded?(other : self,
              lhs : Element,
              rhs : Templates::Atom | String,
              order : BondOrder? = nil) : Bool
    return false if other.same?(self)
    return false unless b = other[rhs]?
    @atoms.any? do |a|
      if a === lhs && (bond = a.bonds[b]?)
        bond.order == (order || bond.order)
      end
    end
  end

  # :ditto:
  def bonded?(other : self, lhs : Element, rhs : Element, order : BondOrder? = nil) : Bool
    return false if other.same?(self)
    @atoms.any? do |a|
      next unless a === lhs
      other.atoms.any? do |b|
        if b === rhs && (bond = a.bonds[b]?)
          bond.order == (order || bond.order)
        end
      end
    end
  end

  # Returns bonded residues. Residues may be bonded through any atom.
  # Residues are ordered by their chain id, residue number and
  # insertion code if present (refer to #<=>).
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
    residues = [] of Residue
    each_bonded_residue { |residue| residues << residue }
    residues.sort!
  end

  # Returns residues bonded through *bond_t*. Residues are ordered by
  # their chain id, residue number and insertion code if present
  # (refer to #<=>).
  #
  # ```
  # # Covalent ligand (JG7) is bonded to CYS sidechain
  # residues = Structure.read("ala-cys-thr-jg7.pdb").residues
  # bond_t = Templates::Bond.new("C", "N")
  # residues[0].bonded_residues(bond_t).map(&.name) # => ["CYS"]
  # residues[1].bonded_residues(bond_t).map(&.name) # => ["THR"]
  # residues[2].bonded_residues(bond_t).map(&.name) # => []
  # residues[3].bonded_residues(bond_t).map(&.name) # => []
  # ```
  #
  # If *forward_only* is `false`, then bond directionality is ignored:
  #
  # ```
  # residues[0].bonded_residues(bond_t, forward_only: false).map(&.name) # => ["CYS"]
  # residues[1].bonded_residues(bond_t, forward_only: false).map(&.name) # => ["ALA", "THR"]
  # residues[2].bonded_residues(bond_t, forward_only: false).map(&.name) # => ["CYS"]
  # residues[3].bonded_residues(bond_t, forward_only: false).map(&.name) # => []
  # ```
  #
  # If *strict* is `false`, bond search checks elements only, and bond
  # order is ignored (fuzzy search). In the following example, using
  # `strict: false` makes that any C-N bond is accepted regardless of
  # atom names or bond order:
  #
  # ```
  # bond_t = Templates::Bond.new "C", "NX", order: 2
  # residues[0].bonded_residues(bond_t, strict: false).map(&.name) # => ["CYS"]
  # residues[1].bonded_residues(bond_t, strict: false).map(&.name) # => ["THR"]
  # residues[2].bonded_residues(bond_t, strict: false).map(&.name) # => []
  # residues[3].bonded_residues(bond_t, strict: false).map(&.name) # => []
  # ```
  def bonded_residues(bond_t : Templates::Bond,
                      forward_only : Bool = true,
                      strict : Bool = true) : Array(Residue)
    residues = [] of Residue
    each_bonded_residue(bond_t, forward_only, strict) { |residue| residues << residue }
    residues
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

  # Returns a single-letter code associated with the residue's
  # template. If the residue has no associated template or it doesn't
  # have a code, the method returns *default*.
  def code(default : Char = 'X') : Char
    template.try(&.code) || default
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

  # Yields each bonded residue. Residues may be bonded through any
  # atom.
  #
  # See `#bonded_residues` for examples.
  def each_bonded_residue(& : Residue ->) : Nil
    residues = Set(Residue).new
    @atoms.each do |atom|
      atom.each_bonded_atom do |other|
        residue = other.residue
        yield residue if residue != self && !residue.in?(residues)
        residues << residue
      end
    end
  end

  # Yields each residue bonded through *bond_t*.
  #
  # If *forward_only* is `false`, then bond directionality is ignored.
  #
  # If *strict* is `false`, bond search checks elements only, and bond
  # order is ignored (fuzzy search).
  #
  # See `#bonded_residues(bond_t, forward_only, strict)` for examples.
  def each_bonded_residue(bond_t : Templates::Bond,
                          forward_only : Bool = true,
                          strict : Bool = true,
                          & : Residue ->) : Nil
    each_bonded_residue do |residue|
      bonded = bonded?(residue, bond_t, strict)
      bonded ||= residue.bonded?(self, bond_t, strict) unless forward_only
      yield residue if bonded
    end
  end

  def has_backbone? : Bool
    !self["N"]?.nil? && !self["CA"]?.nil? && !self["C"]?.nil? && !self["O"]?.nil?
  end

  # Returns `true` if the residue is a non-standard (HET) residue,
  # else `false`.
  def het? : Bool
    !protein?
  end

  def hlxparams : Protein::HlxParams?
    Protein::HlxParams.new self
  rescue ArgumentError | KeyError
    nil
  end

  # Returns `true` if the residue contains _atom_, else `false`.
  #
  # The check is done by name first, and then by atom equality.
  def includes?(atom : Atom) : Bool
    @atom_table[atom.name]? == atom
  end

  def insertion_code=(insertion_code : Char?) : Char?
    @insertion_code = insertion_code
    @chain.reset_cache
    @insertion_code
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

  # Returns `true` if the residue number equals the given number, else
  # `false`.
  def matches?(number : Int) : Bool
    @number == number
  end

  # Returns `true` if the residue name equals the given name, else
  # `false`.
  def matches?(str : String) : Bool
    @name == str
  end

  # Returns `true` if the residue code equals the given character, else
  # `false`.
  def matches?(code : Char) : Bool
    self.code == code
  end

  # Returns `true` if the residue name matches the given pattern, else
  # `false`.
  def matches?(pattern : Regex) : Bool
    @name.matches? pattern
  end

  # Returns `true` if the residue number is included in the given range,
  # else `false`.
  def matches?(numbers : Range(Int, Int) | Range(Nil, Int) | Range(Int, Nil) | Range(Nil, Nil)) : Bool
    @number.in? numbers
  end

  # Returns `true` if the residue number is included in the given
  # numbers, else `false`.
  def matches?(numbers : Enumerable(Int)) : Bool
    @number.in? numbers
  end

  # Returns `true` if the residue name is included in the given
  # names, else `false`.
  def matches?(names : Enumerable(String)) : Bool
    @name.in? names
  end

  # Returns `true` if the residue code is included in the given
  # characters, else `false`.
  def matches?(codes : Enumerable(Char)) : Bool
    code.in? codes
  end

  def name=(str : String) : String
    @name = str
    assign_type_from_templates
    str
  end

  def number=(number : Int32) : Int32
    @number = number
    @chain.reset_cache
    @number
  end

  # Returns the following residue if exists, else raises `Error`.
  # Refer to `#succ?` for details.
  def succ(strict : Bool = true, use_numbering : Bool = true) : Residue
    succ?(strict, use_numbering) || raise Error.new("No residue follows #{self}")
  end

  # Returns the following residue if exists, otherwise `nil`.
  #
  # It uses the link bond type of the associated residue template, if
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
  def succ?(strict : Bool = true, use_numbering : Bool = true) : Residue?
    bonded_residue = nil
    if bond_t = template.try(&.link_bond)
      each_bonded_residue(bond_t, strict: strict) do |residue|
        bonded_residue = residue if !bonded_residue || residue < bonded_residue
      end
    elsif use_numbering
      each_bonded_residue do |residue|
        if residue > self && (!bonded_residue || residue < bonded_residue)
          bonded_residue = residue
        end
      end
    end
    bonded_residue
  end

  def omega : Float64
    omega? || raise Error.new "#{self} is terminal"
  end

  def omega? : Float64?
    if (ca1 = pred?.try(&.[]?("CA"))) &&
       (c = pred?.try(&.[]?("C"))) &&
       (n = self["N"]?) &&
       (ca2 = self["CA"]?)
      if cell = structure.cell?
        Spatial.dihedral cell, ca1, c, n, ca2
      else
        Spatial.dihedral ca1, c, n, ca2
      end
    end
  end

  def phi : Float64
    phi? || raise Error.new "#{self} is terminal"
  end

  def phi? : Float64?
    if (ca1 = pred?.try(&.[]?("C"))) &&
       (n = self["N"]?) &&
       (ca2 = self["CA"]?) &&
       (c = self["C"]?)
      if cell = structure.cell?
        Spatial.dihedral cell, ca1, n, ca2, c
      else
        Spatial.dihedral ca1, n, ca2, c
      end
    end
  end

  # Returns the preceding residue if exists, else raises `Error`.
  # Refer to `#pred?` for details.
  def pred(strict : Bool = true, use_numbering : Bool = true) : Residue
    pred?(strict, use_numbering) || raise Error.new("No residue precedes #{self}")
  end

  # Returns the preceding residue if exists, otherwise `nil`.
  #
  # It uses the link bond type of the associated residue template, if
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
  def pred?(strict : Bool = true, use_numbering : Bool = true) : Residue?
    bonded_residue = nil
    if bond_t = template.try(&.link_bond)
      each_bonded_residue(bond_t.reverse, strict: strict) do |residue|
        bonded_residue = residue if !bonded_residue || residue > bonded_residue
      end
    elsif use_numbering
      each_bonded_residue do |residue|
        if residue < self && (!bonded_residue || residue > bonded_residue)
          bonded_residue = residue
        end
      end
    end
    bonded_residue
  end

  def psi : Float64
    psi? || raise Error.new "#{self} is terminal"
  end

  def psi? : Float64?
    if (n1 = self["N"]?) &&
       (ca = self["CA"]?) &&
       (c = self["C"]?) &&
       (n2 = succ?.try(&.[]?("N")))
      if cell = structure.cell?
        Spatial.dihedral cell, n1, ca, c, n2
      else
        Spatial.dihedral n1, ca, c, n2
      end
    end
  end

  def polymer? : Bool
    !!(template.try(&.polymer?) || protein? || dna?)
  end

  def ramachandran_angles : Tuple(Float64, Float64)
    {phi, psi}
  end

  # Returns the residue specification.
  #
  # Residue specification is a short string representation encoding
  # residue information including chain, name, number, and insertion
  # code.
  def spec : String
    String.build do |io|
      spec io
    end
  end

  # Writes the residue specification to the given IO.
  #
  # Residue specification is a short string representation encoding
  # residue information including chain, name, number, and insertion
  # code.
  def spec(io : IO) : Nil
    chain.spec io
    io << ':'
    io << @name
    io << @number
    io << @insertion_code
  end

  def to_s(io : IO)
    io << '<' << {{@type.name.split("::").last}} << ' '
    spec io
    io << '>'
  end

  def trans? : Bool
    (angle = omega?) ? angle.abs > 150 : false
  end

  # Returns associated residue template if registered, otherwise nil.
  #
  # The template is fetched by the residue name.
  def template : Templates::Residue?
    Templates::Registry.default[@name]?
  end

  # Returns `true` if the residue is a water residue, else `false`.
  # This is done by checking if the associated residue template (if
  # any) correspond to the water template.
  def water? : Bool
    !!(template.try &.name.==("HOH"))
  end

  {% for member in ResidueType.constants %}
      {% typename = member == "DNA" ? member : member.downcase %}
      {% desc = member != "Other" ? "a #{typename}" : "an unknown" %}
      # Returns `true` if the residue is {{desc.id}} residue, else `false`.
      def {{member.underscore.id}}? : Bool
        @type == ResidueType::{{member}}
      end
    {% end %}

  private def assign_type_from_templates : Nil
    @type = template.try(&.type) || ResidueType::Other
  end

  # Copies `self` into *chain*. It calls `#copy_to` on each atom if
  # *recursive* is `true`.
  #
  # NOTE: bonds are not copied and must be set manually for the copy.
  protected def copy_to(chain : Chain, recursive : Bool = true) : self
    residue = Residue.new chain, @number, @insertion_code, @name
    residue.type = @type
    residue.sec = @sec
    atoms.each &.copy_to(residue) if recursive
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
