module Chem
  ResidueType.register do
    description "Water"
    name "HOH"
    aliases "WAT", "TIP3"
    kind :solvent
    structure do
      stem "O"
    end
  end
end
