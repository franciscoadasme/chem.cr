module Chem
  # TODO rename `charge` to `formal_charge`
  # TODO add `partial_charge : Float64 = 0.0`
  # TODO add `residue_index` that starts from 0 and does not reset per chain
  class Atom
    getter bonds : BondArray { BondArray.new self }
    property constraint : Constraint?
    property coords : Spatial::Vector
    property element : Element
    property formal_charge : Int32 = 0
    property name : String
    property mass : Float64
    property occupancy : Float64 = 1
    property partial_charge : Float64 = 0.0
    property residue : Residue
    property serial : Int32
    property temperature_factor : Float64 = 0
    property vdw_radius : Float64

    delegate x, y, z, to: @coords
    delegate chain, to: @residue
    delegate atomic_number, covalent_radius, max_valency, to: @element

    def initialize(@name : String,
                   @serial : Int32,
                   @coords : Spatial::Vector,
                   @residue : Residue,
                   element : Element? = nil,
                   @formal_charge : Int32 = 0,
                   mass : Number? = nil,
                   @occupancy : Float64 = 1,
                   @partial_charge : Float64 = 0.0,
                   @temperature_factor : Float64 = 0,
                   vdw_radius : Number? = nil)
      @element = element || PeriodicTable[atom_name: @name]
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
    #        when Topology::AtomType("C")  then "carbonyl carbon"
    #        when Topology::AtomType("CA") then "alpha carbon"
    #        when Topology::AtomType("CB") then "beta carbon"
    #        when Topology::AtomType("CG") then "gamma carbon"
    #        when Topology::AtomType("CD") then "delta carbon"
    #        when PeriodicTable::C         then "carbon"
    #        else                               "non-carbon"
    #        end
    # desc # => "alpha carbon"
    # ```
    def ===(atom_t : Topology::AtomType) : Bool
      match? atom_t
    end

    # Case equality. Returns true if atom's element is *element*,
    # otherwise false.
    #
    # ```
    # structure = Structure.read "peptide.pdb"
    # desc = case structure.dig('A', 5, "CK")
    #        when Topology::AtomType("C")  then "carbonyl carbon"
    #        when Topology::AtomType("CA") then "alpha carbon"
    #        when Topology::AtomType("CB") then "beta carbon"
    #        when Topology::AtomType("CG") then "gamma carbon"
    #        when Topology::AtomType("CD") then "delta carbon"
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
    def <=>(rhs : self) : Int32
      @serial <=> rhs.serial
    end

    def bonded?(to other : self) : Bool
      !bonds[other]?.nil?
    end

    def bonded_atoms : Array(Atom)
      bonds.map &.other(self)
    end

    def each_bonded_atom : Iterator(Atom)
      bonds.each.map(&.other(self))
    end

    def each_bonded_atom(& : self ->) : Nil
      bonds.each do |bond|
        yield bond.other(self)
      end
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
    # atom.match?(Topology::AtomType.new("CA"))               # => true
    # atom.match?(Topology::AtomType.new("CA", element: "N")) # => false
    # atom.match?(Topology::AtomType.new("ND2"))              # => false
    # ```
    def match?(atom_t : Topology::AtomType) : Bool
      @name == atom_t.name && @element == atom_t.element
    end

    def missing_valency : Int32
      (nominal_valency - valency).clamp 0..
    end

    def nominal_valency : Int32
      @element.valencies.find(&.>=(valency)) || max_valency
    end

    def residue=(new_res : Residue) : Residue
      @residue.delete self
      @residue = new_res
      new_res << self
    end

    def to_s(io : IO)
      io << @residue
      io << ':' << @name << '(' << @serial << ')'
    end

    def valency : Int32
      if element.ionic?
        @element.max_valency
      else
        bonds.sum(&.order) - @formal_charge
      end
    end

    def within_covalent_distance?(rhs : self) : Bool
      Spatial.squared_distance(self, rhs) <= PeriodicTable.covalent_cutoff(self, rhs)
    end

    # Copies `self` into *residue*
    #
    # NOTE: bonds are not copied and must be set manually for the copy.
    protected def copy_to(residue : Residue) : self
      atom = Atom.new @name, @serial, @coords, residue, @element, @formal_charge,
        @occupancy, @partial_charge, @temperature_factor
      atom.constraint = @constraint
      atom
    end
  end
end
