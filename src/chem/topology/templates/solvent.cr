module Chem
  ResidueType.register do
    description "Water"
    names "HOH", "WAT"
    kind :solvent
    structure do
      stem "O"
    end
  end
end
