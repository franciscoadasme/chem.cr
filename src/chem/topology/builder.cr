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

    private def missing_bonds(atom : Atom) : Int32
      guess_nominal_valency_from_connectivity(atom) - atom.valency
    end
  end
end
