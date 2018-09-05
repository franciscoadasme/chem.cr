module Chem::Topology::Templates
  struct Bond
    enum Order
      Single
      Double
      Triple
      Aromatic

      def to_i : Int32
        value + 1
      end
    end

    getter atom1 : String
    getter atom2 : String
    getter order : Order

    def initialize(@atom1, @atom2, @order)
    end

    def ==(other : Bond) : Bool
      return false if @order != other.order
      return true if @atom1 == other.atom1 && @atom2 == other.atom2
      @atom1 == other.atom2 && @atom2 == other.atom1
    end

    def has_atom?(atom_name) : Bool
      @atom1 == atom_name || @atom2 == atom_name
    end
  end

  enum Kind
    Protein
    DNA
    Ion
    Solvent
    Other
  end

  class Residue
    @atom_names : Array(String)
    @bonds : Array(Bond)
    @formal_charges : Array(Int32)

    getter code : String
    getter name : String
    getter kind : Kind
    getter symbol : Char

    def initialize(@name : String,
                   @code : String,
                   @symbol : Char,
                   @kind : Kind,
                   atom_names : Array(String),
                   formal_charges : Array(Int32),
                   bonds : Array(Bond))
      @atom_names = atom_names.dup
      @bonds = bonds.dup
      @formal_charges = formal_charges.dup
    end

    def atom_names
      @atom_names.dup
    end

    def bonds
      @bonds.dup
    end

    def formal_charge
      @formal_charges.sum
    end
  end
end
