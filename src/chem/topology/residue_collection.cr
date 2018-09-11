module Chem
  module ResidueCollection
    abstract def each_residue : Iterator(Residue)

    def each_residue(&block : Residue ->)
      each_residue.each &block
    end

    def residues : ResidueView
      ResidueView.new each_residue.to_a
    end
  end
end
