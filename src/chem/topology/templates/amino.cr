module Chem
  ResidueType.register do
    description "Alanine"
    name "ALA"
    code 'A'
    kind :protein
    structure "{backbone}-CB"
  end

  ResidueType.register do
    description "Arginine"
    name "ARG"
    code 'R'
    kind :protein
    structure "{backbone}-CB-CG-CD-NE-CZ(-NH1)=[NH2H2+]"
  end

  ResidueType.register do
    description "Aspartate"
    name "ASH"
    code 'D'
    kind :protein
    structure "{backbone}-CB-CG(=OD1)-OD2"
  end

  ResidueType.register do
    description "Asparagine"
    name "ASN"
    code 'N'
    kind :protein
    structure "{backbone}-CB-CG(-ND2)=OD1"
  end

  ResidueType.register do
    description "Aspartate"
    name "ASP"
    code 'D'
    kind :protein
    structure "{backbone}-CB-CG(=OD1)-[OD2-]"
  end

  ResidueType.register do
    description "Cysteine"
    name "CYS"
    code 'C'
    kind :protein
    structure "{backbone}-CB-SG"
  end

  ResidueType.register do
    description "Cysteine"
    name "CYX"
    code 'C'
    kind :protein
    structure "{backbone}-CB-SG-*"
  end

  ResidueType.register do
    description "Glutamate"
    name "GLH"
    code 'E'
    kind :protein
    structure "{backbone}-CB-CG-CD(=OE1)-OE2"
  end

  ResidueType.register do
    description "Glutamine"
    name "GLN"
    code 'Q'
    kind :protein
    structure "{backbone}-CB-CG-CD(=OE1)-NE2"
  end

  ResidueType.register do
    description "Glutamate"
    name "GLU"
    code 'E'
    kind :protein
    structure "{backbone}-CB-CG-CD(=OE1)-[OE2-]"
  end

  ResidueType.register do
    description "Glycine"
    name "GLY"
    code 'G'
    kind :protein
    structure "N(-H)-CA(-C=O)"
  end

  ResidueType.register do
    description "Histidine"
    name "HIS", "HID", "HSD"
    code 'H'
    kind :protein
    structure "{backbone}-CB-CG%1=CD2-NE2=CE1-ND1-%1"
  end

  ResidueType.register do
    description "Histidine"
    name "HIE", "HSE"
    code 'H'
    kind :protein
    structure "{backbone}-CB-CG%1=CD2-NE2-CE1=ND1-%1"
  end

  ResidueType.register do
    description "Histidine"
    name "HIP", "HSP"
    code 'H'
    kind :protein
    structure "{backbone}-CB-CG%1=CD2-[NE2H+]=CE1-ND1-%1"
  end

  ResidueType.register do
    description "Isoleucine"
    name "ILE"
    code 'I'
    kind :protein
    structure "{backbone}-CB(-CG1-CD1)-CG2"
  end

  ResidueType.register do
    description "Leucine"
    name "LEU"
    code 'L'
    kind :protein
    structure "{backbone}-CB-CG(-CD1)-CD2"
    symmetry({"CD1", "CD2"})
  end

  ResidueType.register do
    description "Lysine"
    name "LYS"
    code 'K'
    kind :protein
    structure "{backbone}-CB-CG-CD-CE-[NZH3+]"
  end

  ResidueType.register do
    description "Methionine "
    name "MET"
    code 'M'
    kind :protein
    structure "{backbone}-CB-CG-SD-CE"
  end

  ResidueType.register do
    description "Phenylalanine"
    name "PHE"
    code 'F'
    kind :protein
    structure "{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1"
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  ResidueType.register do
    description "Proline"
    name "PRO"
    code 'P'
    kind :protein
    structure "N%1-CA(-C=O)-CB-CG-CD-%1"
  end

  ResidueType.register do
    description "Serine"
    name "SER"
    code 'S'
    kind :protein
    structure "{backbone}-CB-OG"
  end

  ResidueType.register do
    description "Threonine"
    name "THR"
    code 'T'
    kind :protein
    structure "{backbone}-CB(-OG1)-CG2"
  end

  ResidueType.register do
    description "Tryptophan"
    name "TRP"
    code 'W'
    kind :protein
    structure "{backbone}-CB-CG%1=CD1-NE1-CE2(-CZ2=CH2-CZ3=CE3-CD2%2)=%2-%1"
  end

  ResidueType.register do
    description "Tyrosine"
    name "TYR"
    code 'Y'
    kind :protein
    structure "{backbone}-CB-CG%1=CD1-CE1=CZ(-OH)-CE2=CD2-%1"
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  ResidueType.register do
    description "Valine"
    name "VAL"
    code 'V'
    kind :protein
    structure "{backbone}-CB(-CG1)-CG2"
    symmetry({"CG1", "CG2"})
  end
end
