module Chem
  class Atom
    include Comparable(Atom)

    getter bonds : BondArray { BondArray.new self }
    property constraint : Spatial::Direction?
    property pos : Spatial::Vec3
    property element : Element
    property formal_charge : Int32 = 0
    property name : String
    property mass : Float64
    property occupancy : Float64 = 1
    property partial_charge : Float64 = 0.0
    # Parent structure.
    getter structure : Structure
    # Parent residue. Raises if the atom is not in a residue. Use
    # `#residue?` when hierarchy may be absent.
    getter! residue : Residue
    property number : Int32
    property temperature_factor : Float64 = 0
    # Atom typename. Usually specifies the atomic parameter set assigned
    # to this atom within a given force field.
    property typename : String?
    property vdw_radius : Float64
    # Hash-like container that stores the atom's additional properties
    # as key (string)-value pairs. A property's value can be any of the
    # primitive types (string, integer, float, or bool), and so it's
    # internally stored as `Metadata::Any`. Use the cast methods
    # (`#as_*`) to convert to the desired type.
    #
    # ```
    # atom.metadata["foo"] = 123
    # atom.metadata["foo"]      # => Metadata::Any(123)
    # atom.metadata["foo"].as_i # => 123
    # atom.metadata["foo"].as_f # => 123.0
    # atom.metadata["foo"].as_s # raises TypeCastError
    # ```
    getter metadata : Metadata { Metadata.new }

    delegate x, y, z, to: @pos
    delegate atomic_number, covalent_radius, heavy?, max_valence, valence_electrons, to: @element

    def initialize(
      @structure : Structure,
      @number : Int32,
      @element : Element,
      @name : String,
      @pos : Spatial::Vec3,
      @typename : String? = nil,
      @formal_charge : Int32 = 0,
      @mass : Float64 = element.mass,
      @occupancy : Float64 = 1,
      @partial_charge : Float64 = 0.0,
      @temperature_factor : Float64 = 0,
      @vdw_radius : Float64 = element.vdw_radius,
      residue : Residue? = nil,
    )
      raise ArgumentError.new("Negative mass") if @mass < 0
      raise ArgumentError.new("Negative vdW radius") if @vdw_radius < 0
      if residue
        unless residue.structure.same?(@structure)
          raise ArgumentError.new("Residue does not belong to the given structure")
        end
        if @structure.atoms.any? { |atom| atom.residue?.nil? }
          raise ArgumentError.new("Cannot mix atoms with and without topology")
        end
      elsif @structure.has_topology?
        raise ArgumentError.new("Structure has topology; atom must belong to a residue")
      end
      @residue = residue
      @structure << self
      residue.try &.<<(self)
    end

    # Creates an atom in *residue* (and its parent structure).
    def self.new(
      residue : Residue,
      number : Int32,
      element : Element,
      name : String,
      pos : Spatial::Vec3,
      **options,
    ) : self
      new(residue.structure, number, element, name, pos, **options, residue: residue)
    end

    # Returns the parent chain. Raises if the atom has no residue.
    def chain : Chain
      residue.chain
    end

    # Returns the parent chain, or `nil` if the atom has no residue.
    def chain? : Chain?
      residue?.try(&.chain)
    end

    # The comparison operator.
    #
    # Returns `-1`, `0` or `1` depending on whether `self` precedes
    # *rhs*, equals to *rhs* or comes after *rhs*. The comparison is
    # done based on atom number.
    #
    # ```
    # atoms = Structure.read("peptide.pdb").atoms
    #
    # atoms[0] <=> atoms[1] # => -1
    # atoms[1] <=> atoms[1] # => 0
    # atoms[2] <=> atoms[1] # => 1
    # ```
    def <=>(other : self) : Int32
      @number <=> other.number
    end

    # Returns `true` if `self` and *rhs* are the same atom, else
    # `false`.
    #
    # NOTE: overrides the equality operator included by `Comparable`,
    # which uses the `<=>` operator thus returning true for two
    # different atoms that have the same number.
    def ==(rhs : self) : Bool
      same?(rhs)
    end

    def bonded?(to other : self) : Bool
      bonds.any? &.other(self).==(other)
    end

    def bonded_atoms : Array(Atom)
      bonds.map &.other(self)
    end

    # Returns the number of bonds.
    def degree : Int32
      bonds.size
    end

    def each_bonded_atom : Iterator(Atom)
      bonds.each.map(&.other(self))
    end

    def each_bonded_atom(& : self ->) : Nil
      bonds.each do |bond|
        yield bond.other(self)
      end
    end

    # Returns `true` if the atom belongs to a non-standard (HET)
    # residue, else `false`.
    def het? : Bool
      residue?.try(&.het?) || false
    end

    def inspect(io : IO) : Nil
      to_s io
    end

    # Returns `true` if the atom number equals the given number, else
    # `false`.
    def matches?(number : Int) : Bool
      @number == number
    end

    # Returns `true` if the atom name equals the given name, else
    # `false`.
    def matches?(str : String) : Bool
      @name == str
    end

    # Returns `true` if the atom name matches the given pattern, else
    # `false`.
    def matches?(pattern : Regex) : Bool
      @name.matches? pattern
    end

    # Returns `true` if the atom's element equals the given element,
    # else `false`.
    def matches?(element : Element) : Bool
      @element == element
    end

    # Returns `true` if the atom number is included in the given range,
    # else `false`.
    def matches?(numbers : Range(Int, Int) | Range(Nil, Int) | Range(Int, Nil) | Range(Nil, Nil)) : Bool
      @number.in? numbers
    end

    # Returns `true` if the atom number is included in the given
    # numbers, else `false`.
    def matches?(numbers : Enumerable(Int)) : Bool
      @number.in? numbers
    end

    # Returns `true` if the atom name is included in the given
    # names, else `false`.
    def matches?(names : Enumerable(String)) : Bool
      @name.in? names
    end

    # Returns `true` if the atom matches the given template, else
    # `false`.
    #
    # Checking for a match considers both atom name and element.
    #
    # ```
    # atom = Structure.read("peptide.pdb").dig 'A', 1, "CA"
    # atom.match?(Templates::Atom.new("CA"))               # => true
    # atom.match?(Templates::Atom.new("CA", element: "N")) # => false
    # atom.match?(Templates::Atom.new("ND2"))              # => false
    # ```
    # TODO: compare topology via Templates::Atom#top_spec
    def matches?(atom_t : Templates::Atom) : Bool
      @name == atom_t.name && @element == atom_t.element
    end

    def missing_valence : Int32
      (target_valence - valence).clamp 0..
    end

    # Removes the atom from its parent structure and residue, and
    # deletes its bonds.
    def delete : Nil
      @structure.delete self
    end

    # Assigns the parent residue. To remove the atom from the structure,
    # use `#delete`.
    def residue=(new_res : Residue) : Residue
      return new_res if @residue.same?(new_res)
      unless new_res.structure.same?(@structure)
        raise ArgumentError.new("Residue does not belong to the atom's structure")
      end
      @residue.try &.delete(self)
      @residue = new_res
      new_res << self
      new_res
    end

    # Returns the atom specification.
    #
    # Atom specification is a short string representation encoding atom
    # information including chain, residue, atom name, and atom number.
    def spec : String
      String.build do |io|
        spec io
      end
    end

    # Writes the atom specification to the given IO.
    #
    # Atom specification is a short string representation encoding atom
    # information including chain, residue, atom name, and atom number.
    def spec(io : IO) : Nil
      if residue = @residue
        residue.spec io
        io << ':'
      end
      io << @name << '(' << @number << ')'
    end

    # Returns the target valence based on the effective valence. This is
    # useful for multi-valent elements (e.g., sulfur, phosphorus).
    def target_valence : Int32
      @element.target_valence(valence)
    end

    # Returns `true` if the atom is connected to one heavy atom
    # (hydrogens are ignored), else `false`. This is useful to detect
    # terminal functional groups such as -CH₃, -NH₂, etc.
    def terminal? : Bool
      bonds.count(&.other(self).heavy?) == 1
    end

    def to_s(io : IO)
      io << '<' << {{@type.name.split("::").last}} << ' '
      spec io
      io << '>'
    end

    # Returns the effective valence. This is equivalent to the sum of
    # the bond orders.
    def valence : Int32
      bonds.sum(&.order.to_i)
    end

    # Returns `true` if the atom belongs to a water residue, else
    # `false`.
    def water? : Bool
      residue?.try(&.water?) || false
    end

    def within_covalent_distance?(rhs : self) : Bool
      Spatial.distance2(self, rhs) <= PeriodicTable.covalent_cutoff(self, rhs)
    end

    {% for member in ResidueType.constants %}
      # Returns `true` if the atom belongs to a {{member.downcase}}
      # residue, else `false`.
      def {{member.underscore.id}}? : Bool
        residue?.try(&.{{member.underscore.id}}?) || false
      end
    {% end %}

    macro finished
      {% for constant in PeriodicTable.constants %}
        {% call = PeriodicTable.constant(constant) %} # call to Element#new
        {% name = call.named_args[2].value %}
        {% method_name = (name.downcase + "?").id %}

        # Returns `true` if the atom's element is {{name}}, else
        # `false`.
        def {{method_name}}
          @element.{{method_name}}
        end
      {% end %}
    end

    # Copies `self` into *structure* without a residue.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(structure : Structure) : self
      copy_to structure, residue: nil
    end

    # Copies `self` into *residue*.
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(residue : Residue) : self
      copy_to residue.structure, residue: residue
    end

    private def copy_to(structure : Structure, residue : Residue?) : self
      atom = Atom.new(structure, @number, @element, @name, @pos,
        typename: @typename,
        formal_charge: @formal_charge,
        mass: @mass,
        occupancy: @occupancy,
        partial_charge: @partial_charge,
        temperature_factor: @temperature_factor,
        vdw_radius: @vdw_radius,
        residue: residue)
      atom.constraint = @constraint
      if metadata = @metadata
        atom.metadata.merge! metadata
      end
      atom
    end

    # Unlinks the atom from its residue without removing it from the
    # structure. Used when deleting the atom or stripping topology.
    protected def detach_from_residue : Nil
      if residue = @residue
        residue.delete self
        @residue = nil
      end
    end
  end
end
