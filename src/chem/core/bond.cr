module Chem
  # A `BondOrder` provides a type-safe representation of the bond order
  # of a covalent bond between two atoms.
  enum BondOrder
    # Zero bond order, e.g., Schrodinger represents bonds between metals
    # as zero-order bonds. May also indicate unknown or unspecified
    # order.
    Zero = 0
    # Single bond order
    Single = 1
    # Double bond order
    Double = 2
    # Triple bond order
    Triple = 3

    # Returns `true` if the integer representation of the bond order is
    # equal to *rhs*, else `false`.
    def ==(rhs : Int) : Bool
      to_i == rhs
    end

    # Decreases the bond order. Raises `Error` if the bond order is
    # zero.
    def pred : self
      case self
      in .zero?   then raise Error.new("Cannot decrease order")
      in .single? then Zero
      in .double? then Single
      in .triple? then Double
      end
    end

    # Increases the bond order. Raises `Error` if the bond order is
    # triple.
    def succ : self
      case self
      in .zero?   then Single
      in .single? then Double
      in .double? then Triple
      in .triple? then raise Error.new("Cannot increase order")
      end
    end

    # Returns the char representation of the bond order.
    def to_char : Char
      case self
      in .zero?   then '·'
      in .single? then '-'
      in .double? then '='
      in .triple? then '#'
      end
    end
  end

  # A covalent bond between two atoms.
  class Bond
    getter atoms : {Atom, Atom}
    property order : BondOrder
    delegate zero?, single?, double?, triple?, to: @order

    # Creates a new `Bond` with the given atoms and *order*.
    def initialize(atom : Atom, other : Atom, @order : BondOrder = :single)
      raise ArgumentError.new("Duplicate atom") if atom == other
      @atoms = atom > other ? {other, atom} : {atom, other}
    end

    def ==(rhs : self) : Bool
      @atoms == rhs.atoms
    end

    # Returns `true` if the bond shares an atom with *other*, else
    # `false`.
    def bonded?(other : self) : Bool
      @atoms.any? &.in?(other)
    end

    # Returns `true` if the bond includes *atom*, else `false`.
    def includes?(atom : Atom) : Bool
      atom.in? @atoms
    end

    def inspect(io : IO) : Nil
      io << "<Bond "
      @atoms[0].spec io
      io << @order.to_char
      @atoms[1].spec io
      io << '>'
    end

    # Returns `true` if the bond matches the given template, else
    # `false`.
    #
    # Check considers both atom matching (see `Atom#matches?`) and bond
    # order.
    def matches?(bond_t : Templates::Bond) : Bool
      (bond_t.atoms === @atoms || bond_t.atoms === @atoms.reverse) &&
        @order == bond_t.order
    end

    # Returns the bond length in angstroms.
    def measure : Float64
      Spatial.distance(*@atoms.map(&.pos))
    end

    # Returns the atom bonded to *atom*. Raises `Error` if *atom* is not
    # included in the bond.
    def other(atom : Atom) : Atom
      case atom
      when @atoms[0]
        @atoms[1]
      when @atoms[1]
        @atoms[0]
      else
        raise Error.new("Bond doesn't include #{atom}")
      end
    end

    def to_s(io : IO) : Nil
      io << @atoms[0].name << @order.to_char << @atoms[1].name
    end
  end

  # Kekulizes *bonds* marked as aromatic. Raises an exception when bonds
  # could not be kekulized.
  #
  # Kekulization is the process of assigning double bonds to fill the
  # Lewis structure of the aromatic atoms. Different bond orderings
  # may produce distinct but valid Kekule forms. This procedure
  # requires that all atoms have explicit hydrogens such that unfilled
  # valence is due to missing double bonds only, otherwise it will
  # produce incorrect chemical structures or even fail.
  #
  # This method first groups aromatic bonds by their connectivity.
  # Then, each bond subset (ring) is kekulized independently.
  # Alternating double bonds starting from a root bond are assigned
  # based on the connectivity tree, which is traversed using the
  # iterative breadth-first search (BFS) algorithm. Different root
  # bonds are tested until a valid Kekule form is found. Otherwise, an
  # exception is raised.
  def self.kekulize(bonds : Enumerable(Bond)) : Nil
    bonds = bonds.to_a
    return if bonds.empty?

    grouped_bonds = [] of Array(Bond)
    until bonds.empty?
      group = [bonds.pop]
      until (bonded = bonds.select { |bond| group.any?(&.bonded?(bond)) }).empty?
        group.concat bonded
        bonds.reject! &.in?(bonded)
      end
      grouped_bonds << group
    end

    grouped_bonds.each do |bonds|
      ctab = Hash(Bond, Array(Bond)).new { |hash, key| hash[key] = [] of Bond }
      bonds.each_with_index do |bond, i|
        bonds.each(within: (i + 1)..) do |other|
          next unless other.bonded?(bond)
          ctab[bond] << other
          ctab[other] << bond
        end
      end

      changeable = bonds.select(&.atoms.any?(&.missing_valence.>(0))).to_set
      kekulized = false
      subbonds = [] of Bond
      visited = Set(Bond).new bonds.size
      bonds.size.times do |i|
        next unless bonds[i].in?(changeable)

        subbonds << bonds[i]
        until subbonds.empty?
          bond = subbonds.pop
          next if bond.in?(visited)
          bond.order = :double if bond.in?(changeable) && ctab[bond].all?(&.single?)
          visited << bond
          ctab[bond].each do |other|
            subbonds << other unless other.in?(visited)
          end
        end

        if bonds.all? &.atoms.all? { |atom| atom.target_valence == atom.valence }
          kekulized = true
          break
        end

        bonds.each &.order=(:single)
        subbonds.clear
        visited.clear
      end

      raise "Could not kekulize aromatic ring" unless kekulized
    end
  end
end
