require "../system"
require "./residue"
require "./residue_collection"

module Chem
  class Chain
    include ResidueCollection

    @residues = [] of Residue

    getter identifier : Char?
    getter system : System

    def initialize(@identifier : Char?, @system : System)
    end

    def <<(residue : Residue)
      @residues << residue
    end

    def each_residue : Iterator(Residue)
      @residues.each
    end

    def id : Char?
      @identifier
    end

    def make_residue(**options) : Residue
      options = options.merge({chain: self})
      residue = Residue.new **options
      self << residue
      residue
    end
  end
end
