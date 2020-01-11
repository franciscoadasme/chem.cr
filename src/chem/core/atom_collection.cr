module Chem
  module AtomCollection
    abstract def each_atom : Iterator(Atom)
    abstract def each_atom(&block : Atom ->)
    abstract def n_atoms : Int32

    def atoms : AtomView
      atoms = Array(Atom).new n_atoms
      each_atom { |atom| atoms << atom }
      AtomView.new atoms
    end

    def bonds : Array(Bond)
      bonds = Set(Bond).new
      each_atom { |atom| bonds.concat atom.bonds }
      bonds.to_a
    end

    def coords : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new self
    end

    def each_fragment(&block : AtomView ->) : Nil
      fragment = Set(Atom).new
      visited = Set(Atom).new
      each_atom do |atom|
        next if visited.includes? atom
        collect_connected_atoms atom, fragment, visited
        yield AtomView.new(fragment.to_a)
        fragment.clear
      end
    end

    def formal_charge : Int32
      each_atom.sum &.formal_charge
    end

    def formal_charges : Array(Int32)
      each_atom.map(&.formal_charge).to_a
    end

    def fragments : Array(AtomView)
      fragments = [] of AtomView
      each_fragment { |fragment| fragments << fragment }
      fragments
    end

    def has_hydrogens? : Bool
      each_atom.any?(&.element.hydrogen?)
    end

    private def collect_connected_atoms(atom : Atom,
                                        fragment : Set(Atom),
                                        visited : Set(Atom)) : Nil
      fragment << atom
      visited << atom
      atom.bonded_atoms.each do |other|
        collect_connected_atoms other, fragment, visited unless visited.includes? other
      end
    end
  end
end
