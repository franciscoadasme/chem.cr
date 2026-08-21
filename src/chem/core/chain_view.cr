module Chem
  struct ChainView
    include Array::Wrapper(Chain)

    def atoms : AtomView
      atoms = [] of Atom
      each do |chain|
        chain.residues.each do |residue|
          # #concat(Array) copies memory instead of appending one by one
          atoms.concat residue.atoms.to_unsafe
        end
      end
      AtomView.new atoms
    end

    def residues : ResidueView
      residues = [] of Residue
      each do |chain|
        # #concat(Array) copies memory instead of appending one by one
        residues.concat chain.residues.to_a
      end
      ResidueView.new residues
    end

    # Returns the enclosed array. Mutating it changes the view's source.
    def to_unsafe : Array(Chain)
      @wrapped
    end
  end
end
