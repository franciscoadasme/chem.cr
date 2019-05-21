module Chem::Topology
  class Builder
    MAX_COVALENT_RADIUS = 5.0

    private getter kdtree : Spatial::KDTree do
      Spatial::KDTree.new @structure,
        periodic: !@structure.lattice.nil?,
        radius: MAX_COVALENT_RADIUS
    end

    def initialize(@structure : Structure)
      @covalent_dist_table = {} of Tuple(String, String) => Float64
    end

    def guess_bonds_from_geometry : Nil
      guess_connectivity_from_geometry
      assign_bond_orders
    end

    def guess_topology_from_connectivity : Nil
      raise Error.new "Structure has no bonds" if @structure.bonds.empty?
      return unless old_chain = @structure.delete(@structure.chains.first)

      chains = {} of Residue::Kind => Chain
      detector = Templates::Detector.new Templates.all
      old_chain.fragments.each do |atoms|
        residues, polymer = guess_residues detector, old_chain, atoms.to_a

        id = (65 + @structure.chains.size).chr
        chain = if polymer
                  Chain.new id, @structure
                else
                  chains[residues.first.kind] ||= Chain.new id, @structure
                end
        residues.each do |residue|
          residue.number = chain.residues.size + 1
          residue.chain = chain
        end
      end
    end

    def renumber_by_connectivity : Nil
      raise Error.new "Structure has no bonds" if @structure.bonds.empty?
      @structure.each_chain do |chain|
        next unless chain.residues.size > 1
        next unless link_bond = chain.each_residue.compact_map do |residue|
                      Templates[residue.name]?.try &.link_bond
                    end.first?

        res_map = chain.each_residue.to_h do |residue|
          {guess_previous_residue(residue, link_bond), residue}
        end
        res_map[nil] = chain.residues.first unless res_map.has_key? nil

        prev_res = nil
        chain.residues.size.times do |i|
          next_res = res_map[prev_res]
          next_res.number = i + 1
          prev_res = next_res
        end
        chain.reset_cache
      end
    end

    private def assign_bond_orders : Nil
      @structure.each_atom do |atom|
        if atom.element.ionic?
          atom.formal_charge = atom.element.max_valency
        else
          missing_bonds = missing_bonds atom
          while missing_bonds > 0
            others = atom.bonded_atoms.select { |other| missing_bonds(other) > 0 }
            break if others.empty?
            others.each(within: ...missing_bonds) do |other|
              atom.bonds[other].order += 1
              missing_bonds -= 1
            end
          end
          atom.formal_charge = -missing_bonds
        end
      end
    end

    private def covalent_cutoff(atom : Atom, other : Atom) : Float64
      @covalent_dist_table[{atom.element.symbol, other.element.symbol}] ||= \
         (atom.covalent_radius + other.covalent_radius + 0.3) ** 2
    end

    private def guess_connectivity_from_geometry : Nil
      @structure.each_atom do |a|
        next if a.element.ionic?
        kdtree.each_neighbor a, within: MAX_COVALENT_RADIUS do |b, sqr_d|
          next if b.element.ionic? || a.bonded?(b) || sqr_d > covalent_cutoff(a, b)
          next unless b.valency < b.element.max_valency
          if a.element.hydrogen? && a.bonds.size == 1
            next unless sqr_d < a.bonds[0].squared_distance
            a.bonds.delete a.bonds[0]
          end
          a.bonds.add b
        end
      end
    end

    private def guess_nominal_valency_from_connectivity(atom : Atom) : Int32
      atom.element.valencies.find(&.>=(atom.valency)) || atom.element.max_valency
    end

    private def guess_previous_residue(residue : Residue,
                                       link_bond : Templates::Bond) : Residue?
      prev_res = nil
      if atom = residue[link_bond.second]?
        prev_res = atom.bonded_atoms.find(&.name.==(link_bond.first)).try &.residue
        prev_res ||= atom.bonded_atoms.find do |atom|
          element = PeriodicTable[atom_name: link_bond.first]
          atom.element == element && atom.residue != residue
        end.try &.residue
      else
        elements = {PeriodicTable[atom_name: link_bond.first],
                    PeriodicTable[atom_name: link_bond.second]}
        residue.each_atom do |atom|
          next unless atom.element == elements[1]
          prev_res = atom.bonded_atoms.find do |atom|
            atom.element == elements[0] && atom.residue != residue
          end.try &.residue
          break if prev_res
        end
      end
      prev_res
    end

    private def guess_residues(detector : Templates::Detector,
                               chain : Chain,
                               atoms : Array(Atom)) : Tuple(Array(Residue), Bool)
      polymer = false
      residues = [] of Residue
      detector.each_match(atoms.dup) do |res_t, atom_map|
        names = res_t.atom_names

        residues << (residue = Residue.new res_t.code, residues.size + 1, chain)
        residue.kind = Residue::Kind.from_value res_t.kind.to_i
        atom_map.to_a.sort_by! { |_, k| names.index(k) || 99 }.each do |atom, name|
          atom.name = name
          atom.residue = residue
          atoms.delete atom
        end
        polymer ||= res_t.monomer?
      end

      unless atoms.empty?
        residues << (residue = Residue.new "UNK", chain.residues.size, chain)
        atoms.each &.residue=(residue)
      end

      {residues, polymer}
    end

    private def missing_bonds(atom : Atom) : Int32
      guess_nominal_valency_from_connectivity(atom) - atom.valency
    end
  end
end
