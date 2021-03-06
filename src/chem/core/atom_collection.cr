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

    def each_fragment(& : AtomView ->) : Nil
      atoms = Set(Atom).new(n_atoms).concat each_atom
      each_atom do |atom|
        next unless atom.in?(atoms)
        atoms.delete atom
        fragment = [atom]
        fragment.each do |a|
          a.each_bonded_atom do |b|
            next unless b.in?(atoms)
            fragment << b
            atoms.delete b
          end
        end
        yield AtomView.new(fragment.sort_by!(&.serial))
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
  end
end
