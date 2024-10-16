module Chem
  # The `Connectivity` mixin provides base functionality for types
  # enclosing bonded atoms such an angle.
  module Connectivity(T)
    include Comparable(self)

    # Returns the current value of the measurement.
    abstract def measure : Float64

    # Returns the bonded atoms.
    getter atoms : T

    # The comparison operator. Returns `0` if the two objects are equal,
    # a negative number if this object is considered less than *other*,
    # a positive number if this object is considered greater than
    # *other*, or `nil` if the two objects are not comparable.
    #
    # ```
    # # Sort in a descending way:
    # [3, 1, 2].sort { |x, y| y <=> x } # => [3, 2, 1]
    #
    # # Sort in an ascending way:
    # [3, 1, 2].sort { |x, y| x <=> y } # => [1, 2, 3]
    # ```
    def <=>(rhs : self) : Int32
      @atoms <=> rhs.atoms
    end

    # Raises if there are duplicate atoms.
    private def check_duplicate : Nil
      @atoms.each_with_index do |atom, i|
        @atoms.each(within: (i + 1)..) do |other|
          raise ArgumentError.new("Duplicate atom") if atom == other
        end
      end
    end

    # Returns `true` if the connectivity involves *atom*, else `false`.
    def includes?(atom : Atom) : Bool
      atom.in? @atoms
    end

    def inspect(io : IO) : Nil
      io << self.class.name << '{'
      @atoms.join io, ", ", &.to_s(io)
      io << '}'
    end

    # Sorts the atoms according to their numbers.
    private def sort! : Nil
      @atoms = @atoms.reverse if @atoms.first > @atoms.last
    end

    def to_s(io : IO) : Nil
      io << self.class.name << '{'
      @atoms.join io, ", ", &.spec(io)
      io << '}'
    end
  end

  # A `BondOrder` provides a type-safe representation of the bond order
  # of a covalent between two atoms.
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

  # A `Bond` provides a canonical representation of a covalent bond
  # between two atoms.
  class Bond
    include Connectivity({Atom, Atom})

    property order : BondOrder
    delegate zero?, single?, double?, triple?, to: @order

    # Creates a new `Bond` with the given atoms and *order*.
    def initialize(atom : Atom, other : Atom, @order : BondOrder = :single)
      @atoms = {atom, other}
      check_duplicate
      sort!
    end

    # Returns `true` if the bond shares an atom with *other*, else
    # `false`.
    def bonded?(other : self) : Bool
      @atoms.any? &.in?(other)
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
    # Check considers both atom matching (see `Atom#match?`) and bond
    # order.
    def matches?(bond_t : Templates::Bond) : Bool
      (bond_t.atoms === @atoms || bond_t.atoms === @atoms.reverse) &&
        @order == bond_t.order
    end

    # Returns the current value of the bond in angstroms.
    def measure : Float64
      Spatial.distance(*@atoms.map(&.coords))
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

  # An `Angle` provides a canonical representation of an angle between
  # three bonded atoms.
  #
  # An angle is defined by two contiguous bonds:
  #
  #     A       C
  #       \   /
  #         B
  #
  # It measures the angle between the two vectors defined by the atoms
  # (A,B) and (B,C).
  struct Angle
    include Connectivity({Atom, Atom, Atom})

    # Creates a new *Angle* with the given atoms.
    def initialize(a1 : Atom, a2 : Atom, a3 : Atom)
      @atoms = {a1, a2, a3}
      check_duplicate
      sort!
    end

    # Returns the current value of the angle in radians.
    def measure : Float64
      Spatial.angle(*@atoms.map(&.coords))
    end
  end

  # A `Dihedral` provides a canonical representation of a dihedral angle
  # between four bonded atoms.
  #
  # A dihedral angle is defined by three contiguous bonds:
  #
  #     A       C
  #       \   /   \
  #         B      D
  #
  # It measures the angle between the two planes defined by the atoms
  # (A,B,C) and (B,C,D).
  struct Dihedral
    include Connectivity({Atom, Atom, Atom, Atom})

    # Creates a new *Dihedral* with the given atoms.
    def initialize(a1 : Atom, a2 : Atom, a3 : Atom, a4 : Atom)
      @atoms = {a1, a2, a3, a4}
      check_duplicate
      sort!
    end

    # Returns the current value of the dihedral angle in radians.
    def measure : Float64
      Spatial.dihedral(*@atoms.map(&.coords))
    end

    private def sort! : Nil
      if Math.max(@atoms[0], @atoms[1]) > Math.max(@atoms[2], @atoms[3])
        @atoms = {@atoms[3], @atoms[2], @atoms[1], @atoms[0]}
      end
    end
  end

  # An `Improper` provides a canonical representation of an improper
  # dihedral angle between four bonded atoms.
  #
  # An improper dihedral angle is defined by three bonds around a
  # central atom:
  #
  #     A       C
  #       \   /
  #         B
  #         |
  #         D
  #
  # It measures the angle between the two planes defined by the atoms
  # (A,B,C) and (C,B,D).
  struct Improper
    include Connectivity({Atom, Atom, Atom, Atom})

    # Creates a new *Improper* with the given atoms.
    def initialize(a1 : Atom, a2 : Atom, a3 : Atom, a4 : Atom)
      @atoms = {a1, a2, a3, a4}
      check_duplicate
      sort!
    end

    # Returns the current value of the improper dihedral angle in
    # radians.
    def measure : Float64
      Spatial.improper(*@atoms.map(&.coords))
    end

    private def sort! : Nil
      arr = StaticArray[@atoms[0], @atoms[2], @atoms[3]].sort!
      @atoms = {arr[0], @atoms[1], arr[1], arr[2]}
    end
  end
end
