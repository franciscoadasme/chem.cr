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
end
