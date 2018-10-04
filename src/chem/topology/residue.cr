module Chem
  class Residue
    include AtomCollection

    @atoms = [] of Atom

    property chain : Chain
    property name : String
    property next : Residue?
    property number : Int32
    property previous : Residue?
    property secondary_structure : Protein::SecondaryStructure = :none

    def initialize(@name : String, @number : Int32, @chain : Chain)
    end

    def <<(atom : Atom)
      @atoms << atom
    end

    delegate dssp, to: @secondary_structure

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def make_atom(**options) : Atom
      options = options.merge({residue: self})
      atom = Atom.new **options
      self << atom
      atom
    end

    def to_s(io : ::IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
    end
  end
end
