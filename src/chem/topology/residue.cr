require "./atom"
require "./atom_collection"
require "./chain"

module Chem
  class Residue
    include AtomCollection

    @atoms = [] of Atom

    property chain : Chain
    property name : String
    property number : Int32

    def initialize(@name : String, @number : Int32, @chain : Chain)
    end

    def <<(atom : Atom)
      @atoms << atom
    end

    def each_atom(&block : Atom ->)
      @atoms.each &block
    end

    def make_atom(**options) : Atom
      options = options.merge({residue: self})
      atom = Atom.new **options
      self << atom
      atom
    end

    delegate size, to: @atoms
  end
end
