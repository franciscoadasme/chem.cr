require "./atom_collection"

module Chem
  module ResidueCollection
    include AtomCollection

    abstract def each_residue(&block : Residue ->)

    def each_atom(&block : Atom ->)
      each_residue do |residue|
        residue.each_atom &block
      end
    end

    def residues : Array(Residue)
      ary = Array(Residue).new
      each_residue { |residue| ary << residue }
      ary
    end

    def size : Int32
      size = 0
      each_residue { |residue| size += residue.size }
      size
    end
  end
end
