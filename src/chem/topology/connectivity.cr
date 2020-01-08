module Chem::Topology
  class ConnectivityRadar
    MAX_COVALENT_RADIUS = 5.0

    def initialize(structure : Structure, bond_orders : Bool? = nil)
      @bond_orders = bond_orders || structure.each_atom.any?(&.element.hydrogen?)
      @kdtree = Spatial::KDTree.new structure, structure.periodic?, radius: MAX_COVALENT_RADIUS
    end

    def detect_bonds(atoms : AtomCollection) : Nil
      build_connectivity atoms
      if @bond_orders
        guess_bond_orders atoms
        guess_formal_charges atoms
      end
    end

    private def build_connectivity(atoms : AtomCollection) : Nil
      atoms.each_atom do |atom|
        next if atom.element.ionic?
        @kdtree.each_neighbor(atom, within: MAX_COVALENT_RADIUS) do |other, d|
          next if other.element.ionic? ||
                  atom.bonded?(other) ||
                  other.valency >= other.max_valency ||
                  d > PeriodicTable.covalent_cutoff(atom, other)
          if atom.element.hydrogen? && atom.bonds.size == 1
            next unless d < atom.bonds[0].squared_distance
            atom.bonds.delete atom.bonds[0]
          end
          atom.bonds.add other
        end
      end
    end

    private def guess_bond_orders(atoms : AtomCollection) : Nil
      atoms.each_atom do |atom|
        next if atom.element.ionic?
        missing_bonds = atom.missing_valency
        while missing_bonds > 0
          others = atom.bonded_atoms.select &.missing_valency.>(0)
          break if others.empty?
          others.each(within: ...missing_bonds) do |other|
            atom.bonds[other].order += 1
            missing_bonds -= 1
          end
        end
      end
    end

    private def guess_formal_charges(atoms : AtomCollection) : Nil
      atoms.each_atom do |atom|
        atom.formal_charge = if atom.element.ionic?
                               atom.max_valency
                             else
                               atom.valency - atom.nominal_valency
                             end
      end
    end
  end
end
