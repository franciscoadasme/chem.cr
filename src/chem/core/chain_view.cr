module Chem
  struct ChainView
    include Array::Wrapper(Chain)

    def [](id : Char) : Chain
      self[id]? || raise IndexError.new
    end

    def []?(id : Char) : Chain?
      find &.id.==(id)
    end

    def atoms : AtomView
      atoms = [] of Atom
      each do |chain|
        chain.residues.each do |residue|
          # #concat(Array) copies memory instead of appending one by one
          atoms.concat residue.atoms.to_a
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
  end
end
