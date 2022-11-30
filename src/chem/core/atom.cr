module Chem
  class Atom
    include Comparable(Atom)

    getter bonds : BondArray { BondArray.new self }
    property constraint : Constraint?
    property coords : Spatial::Vec3
    property element : Element
    property formal_charge : Int32 = 0
    property name : String
    property mass : Float64
    property occupancy : Float64 = 1
    property partial_charge : Float64 = 0.0
    property residue : Residue
    property serial : Int32
    property temperature_factor : Float64 = 0
    # Atom typename. Usually specifies the atomic parameter set assigned
    # to this atom within a given force field.
    property typename : String?
    property vdw_radius : Float64

    delegate x, y, z, to: @coords
    delegate chain, to: @residue
    delegate atomic_number, covalent_radius, heavy?, max_valence, valence_electrons, to: @element

    def initialize(
      @residue : Residue,
      @serial : Int32,
      @element : Element,
      @name : String,
      @coords : Spatial::Vec3,
      type : String? = nil,
      @formal_charge : Int32 = 0,
      mass : Number? = nil,
      @occupancy : Float64 = 1,
      @partial_charge : Float64 = 0.0,
      @temperature_factor : Float64 = 0,
      vdw_radius : Number? = nil
    )
      @mass = if mass
                raise ArgumentError.new("Negative mass") if mass < 0
                mass.to_f
              else
                @element.mass
              end
      @vdw_radius = if vdw_radius
                      raise ArgumentError.new("Negative vdW radius") if vdw_radius < 0
                      vdw_radius.to_f
                    else
                      @element.vdw_radius
                    end
      @residue << self
    end

    # Case equality. This is equivalent to `#match?`.
    #
    # ```
    # structure = Structure.read "peptide.pdb"
    # desc = case structure.dig('A', 5, "CA")
    #        when AtomTemplate("C")  then "carbonyl carbon"
    #        when AtomTemplate("CA") then "alpha carbon"
    #        when AtomTemplate("CB") then "beta carbon"
    #        when AtomTemplate("CG") then "gamma carbon"
    #        when AtomTemplate("CD") then "delta carbon"
    #        when PeriodicTable::C         then "carbon"
    #        else                               "non-carbon"
    #        end
    # desc # => "alpha carbon"
    # ```
    def ===(atom_t : AtomTemplate) : Bool
      match? atom_t
    end

    # Case equality. Returns true if atom's element is *element*,
    # otherwise false.
    #
    # ```
    # structure = Structure.read "peptide.pdb"
    # desc = case structure.dig('A', 5, "CK")
    #        when AtomTemplate("C")  then "carbonyl carbon"
    #        when AtomTemplate("CA") then "alpha carbon"
    #        when AtomTemplate("CB") then "beta carbon"
    #        when AtomTemplate("CG") then "gamma carbon"
    #        when AtomTemplate("CD") then "delta carbon"
    #        when PeriodicTable::C         then "carbon"
    #        else                               "non-carbon"
    #        end
    # desc # => "non-carbon"
    # ```
    def ===(element : Element) : Bool
      @element == element
    end

    # The comparison operator.
    #
    # Returns `-1`, `0` or `1` depending on whether `self` precedes
    # *rhs*, equals to *rhs* or comes after *rhs*. The comparison is
    # done based on atom serial.
    #
    # ```
    # atoms = Structure.read("peptide.pdb").atoms
    #
    # atoms[0] <=> atoms[1] # => -1
    # atoms[1] <=> atoms[1] # => 0
    # atoms[2] <=> atoms[1] # => 1
    # ```
    def <=>(other : self) : Int32
      @serial <=> other.serial
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
      @residue.het?
    end

    def inspect(io : IO)
      io << "<Atom "
      to_s io
      io << ">"
    end

    # Matches *self* against *atom_t*.
    #
    # Checking for a match considers both atom name and element.
    #
    # ```
    # atom = Structure.read("peptide.pdb").dig 'A', 1, "CA"
    # atom.match?(AtomTemplate.new("CA"))               # => true
    # atom.match?(AtomTemplate.new("CA", element: "N")) # => false
    # atom.match?(AtomTemplate.new("ND2"))              # => false
    # ```
    def match?(atom_t : AtomTemplate) : Bool
      @name == atom_t.name && @element == atom_t.element
    end

    def missing_valence : Int32
      (target_valence - valence).clamp 0..
    end

    def residue=(new_res : Residue) : Residue
      @residue.delete self
      @residue = new_res
      new_res << self
    end

    # Returns the target valence based on the effective valence. This is
    # useful for multi-valent elements (e.g., sulfur, phosphorus).
    def target_valence : Int32
      @element.target_valence(valence)
    end

    def to_s(io : IO)
      io << @residue
      io << ':' << @name << '(' << @serial << ')'
    end

    # Returns the effective valence. This is equivalent to the sum of
    # the bond orders.
    def valence : Int32
      bonds.sum(&.order.to_i)
    end

    # Returns `true` if the atom belongs to a water residue, else
    # `false`.
    def water? : Bool
      @residue.water?
    end

    def within_covalent_distance?(rhs : self) : Bool
      Spatial.distance2(self, rhs) <= PeriodicTable.covalent_cutoff(self, rhs)
    end

    {% for member in Residue::Kind.constants %}
      # Returns `true` if the atom belongs to a {{member.downcase}}
      # residue, else `false`.
      def {{member.underscore.id}}? : Bool
        @residue.{{member.underscore.id}}?
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

    # Copies `self` into *residue*
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(residue : Residue) : self
      atom = Atom.new residue, @serial, @element, @name, @coords, @typename,
        @formal_charge, @occupancy, @partial_charge, @temperature_factor
      atom.constraint = @constraint
      atom
    end
  end
end
