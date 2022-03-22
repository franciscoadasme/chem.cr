module Chem::Topology::Templates
  register_type(:solvent) do
    description "Water"
    names "HOH", "WAT"
    structure do
      stem "O"
    end
    root "O"
  end
end
