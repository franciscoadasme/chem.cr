module Chem
  class BondArray
    include Indexable(Bond)

    @atom : Atom
    @bonds : Array(Bond)

    delegate size, unsafe_fetch, to: @bonds

    def initialize(@atom : Atom)
      @bonds = Array(Bond).new @atom.element.max_valence || 0
    end

    def [](atom : Atom) : Bond
      self[atom]? || raise Error.new "Atom #{@atom.number} is not bonded to atom " \
                                     "#{atom.number}"
    end

    def []?(atom : Atom) : Bond?
      find &.includes?(atom)
    end

    def <<(bond : Bond)
      add bond
    end

    def add(bond : Bond) : Bond
      unless bond.in?(@bonds)
        other_bonds = bond.other(@atom).bonds
        push bond
        other_bonds.push bond
      end
      bond
    end

    def add(other : Atom, order : BondOrder = :single) : Bond
      if bond = @bonds.find(&.includes?(other))
        bond
      else
        add Bond.new(@atom, other, order)
      end
    end

    def delete(other : Atom)
      if bond = self[other]?
        delete bond
      end
    end

    def delete(bond : Bond)
      return unless bond.in? @bonds
      @bonds.delete bond
      bond.other(@atom).bonds.delete bond
    end

    protected def push(bond : Bond)
      @bonds << bond
    end
  end
end
