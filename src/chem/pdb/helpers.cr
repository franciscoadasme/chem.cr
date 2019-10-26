module Chem::PDB
  private record SecondaryStructureSegment,
    kind : Protein::SecondaryStructure,
    start : Tuple(Char, Int32, Char?),
    end : Tuple(Char, Int32, Char?)
end
