module Chem
  # The `Connectivity` mixin provides base functionality for types
  # enclosing bonded atoms such an angle.
  module Connectivity(T)
    include Comparable(self)

    # Sorts the atoms according to their serial numbers.
    private abstract def sort! : Nil

    # Returns the current value of the measurement.
    abstract def measure : Float64

    # Returns the bonded atoms.
    getter atoms : T

    # Creates a connectivity object with the given atoms. Raises
    # `ArgumentError` on duplicate atoms.
    #
    # NOTE: Atoms are internally sorted to ensure a canonical
    # representation.
    def initialize(@atoms : T)
      @atoms.each_with_index do |atom, i|
        @atoms.each(within: (i + 1)..) do |other|
          raise ArgumentError.new("Duplicate atom") if atom == other
        end
      end
      sort!
    end

    macro included
      # Returns a new connectivity object. Shorthand for `#new({a, b,
      # ...})`.
      def self.[](*atoms : Atom) : self
        new atoms
      end

      # Returns a new connectivity object. Shorthand for `#new({a, b,
      # ...})`.
      def self.new(*atoms : Atom) : self
        new atoms
      end
    end

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

    def inspect(io : IO) : Nil
      io << self.class.name << '{'
      @atoms.join io, ", ", &.inspect(io)
      io << '}'
    end

    def to_s(io : IO) : Nil
      io << self.class.name << '{'
      @atoms.join io, ", ", &.to_s(io)
      io << '}'
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

    # Returns the current value of the angle in radians.
    def measure : Float64
      Spatial.angle(*@atoms.map(&.coords))
    end

    private def sort! : Nil
      @atoms = {@atoms[2], @atoms[1], @atoms[0]} if @atoms[0] > @atoms[2]
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
