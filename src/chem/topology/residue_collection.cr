module Chem
  module ResidueCollection
    abstract def each_residue : Iterator(Residue)
    abstract def each_residue(&block : Residue ->)

    def residues : ResidueView
      residues = [] of Residue
      each_residue { |residue| residues << residue }
      ResidueView.new residues
    end
  end
end
