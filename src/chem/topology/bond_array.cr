module Chem
  class BondArray
    include Indexable(Bond)

    @atom : Atom
    @bonds : Array(Bond)

    delegate size, unsafe_fetch, to: @bonds

    def initialize(@atom : Atom)
      @bonds = Array(Bond).new @atom.valence
    end

    def [](atom : Atom) : Bond
      self[atom]? || raise Error.new "Atom #{@atom.serial} is not bonded to atom " \
                                     "#{atom.serial}"
    end

    def []?(atom : Atom) : Bond?
      find &.includes?(atom)
    end

    def <<(bond : Bond)
      add bond
    end

    def add(bond : Bond)
      return if @bonds.includes? bond
      other_bonds = bond.other(@atom).bonds
      # validate_bond! bond
      # other_bonds.validate_bond! bond
      push bond
      other_bonds.push bond
    end

    def add(other : Atom, kind : Bond::Kind = :single)
      add Bond.new @atom, other, kind
    end

    def add(other : Atom, order : Int32 = 1)
      add Bond.new @atom, other, order
    end

    def delete(other : Atom)
      if bond = self[other]?
        delete bond
      end
    end

    def delete(bond : Bond)
      return unless @bonds.includes? bond
      @bonds.delete bond
      bond.other(@atom).bonds.delete bond
    end

    def full? : Bool
      missing_bonds.zero?
    end

    private def invalid_valence
      msg = String.build do |builder|
        builder << "Atom #{@atom.serial} "
        if full?
          builder << "has its valence shell already full"
        else
          builder << "has only #{missing_bonds} valence electron"
          builder << 's' if missing_bonds > 1
          builder << " available"
        end
      end
      raise Error.new msg
    end

    private def missing_bonds : Int32
      @atom.valence - @bonds.map(&.order.to_i).sum
    end

    protected def push(bond : Bond)
      @bonds << bond
    end

    protected def validate_bond!(bond : Bond)
      invalid_valence if bond.order > missing_bonds
    end
  end
end
