module Chem
  module ResidueCollection
    abstract def each_residue : Iterator(Residue)
    abstract def each_residue(&block : Residue ->)
    abstract def n_residues : Int32

    def link_bond : Topology::BondType?
      each_residue.compact_map(&.type.try(&.link_bond)).first?
    end

    def residues : ResidueView
      residues = Array(Residue).new n_residues
      each_residue { |residue| residues << residue }
      ResidueView.new residues
    end
  end
end
