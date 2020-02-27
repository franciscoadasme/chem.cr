module Chem
  module ResidueCollection
    abstract def each_residue : Iterator(Residue)
    abstract def each_residue(&block : Residue ->)
    abstract def n_residues : Int32

    def renumber_by_connectivity : Nil
      chains = each_residue.map(&.chain).to_a.uniq!
      chains.each do |chain|
        next unless chain.n_residues > 1
        next unless link_bond = chain.each_residue.compact_map do |residue|
                      Topology::Templates[residue.name]?.try &.link_bond
                    end.first?

        res_map = chain.each_residue.to_h do |residue|
          {guess_previous_residue(residue, link_bond), residue}
        end
        res_map[nil] = chain.residues.first unless res_map.has_key? nil

        prev_res = nil
        chain.n_residues.times do |i|
          next_res = res_map[prev_res]
          next_res.number = i + 1
          prev_res = next_res
        end
        chain.reset_cache
      end
    end

    def residues : ResidueView
      residues = Array(Residue).new n_residues
      each_residue { |residue| residues << residue }
      ResidueView.new residues
    end

    private def guess_previous_residue(residue : Residue, link_bond : Topology::BondType) : Residue?
      prev_res = nil
      if atom = residue[link_bond.second]?
        prev_res = atom.each_bonded_atom.find(&.name.==(link_bond.first)).try &.residue
        prev_res ||= atom.each_bonded_atom.find do |atom|
          element = PeriodicTable[atom_name: link_bond.first]
          atom.element == element && atom.residue != residue
        end.try &.residue
      else
        elements = {PeriodicTable[atom_name: link_bond.first],
                    PeriodicTable[atom_name: link_bond.second]}
        residue.each_atom do |atom|
          next unless atom.element == elements[1]
          prev_res = atom.each_bonded_atom.find do |atom|
            atom.element == elements[0] && atom.residue != residue
          end.try &.residue
          break if prev_res
        end
      end
      prev_res
    end
  end
end
