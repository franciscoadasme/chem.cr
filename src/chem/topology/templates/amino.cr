module Chem
  ResidueTemplate.register do
    description "Alanine"
    name "ALA"
    code 'A'
    type :protein
    spec "{backbone}-CB"
  end

  ResidueTemplate.register do
    description "Arginine"
    name "ARG"
    code 'R'
    type :protein
    spec "{backbone}-CB-CG-CD-NE-CZ(-NH1)=[NH2H2+]"
  end

  ResidueTemplate.register do
    description "Aspartate"
    name "ASH"
    code 'D'
    type :protein
    spec "{backbone}-CB-CG(=OD1)-OD2"
  end

  ResidueTemplate.register do
    description "Asparagine"
    name "ASN"
    code 'N'
    type :protein
    spec "{backbone}-CB-CG(-ND2)=OD1"
  end

  ResidueTemplate.register do
    description "Aspartate"
    name "ASP"
    code 'D'
    type :protein
    spec "{backbone}-CB-CG(=OD1)-[OD2-]"
  end

  ResidueTemplate.register do
    description "Cysteine"
    name "CYS"
    code 'C'
    type :protein
    spec "{backbone}-CB-SG"
  end

  ResidueTemplate.register do
    description "Cysteine"
    name "CYX"
    code 'C'
    type :protein
    spec "{backbone}-CB-SG-*"
  end

  ResidueTemplate.register do
    description "Glutamate"
    name "GLH"
    code 'E'
    type :protein
    spec "{backbone}-CB-CG-CD(=OE1)-OE2"
  end

  ResidueTemplate.register do
    description "Glutamine"
    name "GLN"
    code 'Q'
    type :protein
    spec "{backbone}-CB-CG-CD(=OE1)-NE2"
  end

  ResidueTemplate.register do
    description "Glutamate"
    name "GLU"
    code 'E'
    type :protein
    spec "{backbone}-CB-CG-CD(=OE1)-[OE2-]"
  end

  ResidueTemplate.register do
    description "Glycine"
    name "GLY"
    code 'G'
    type :protein
    spec "N(-H)-CA(-C=O)"
  end

  ResidueTemplate.register do
    description "Histidine"
    name "HIS", "HID", "HSD"
    code 'H'
    type :protein
    spec "{backbone}-CB-CG%1=CD2-NE2=CE1-ND1-%1"
  end

  ResidueTemplate.register do
    description "Histidine"
    name "HIE", "HSE"
    code 'H'
    type :protein
    spec "{backbone}-CB-CG%1=CD2-NE2-CE1=ND1-%1"
  end

  ResidueTemplate.register do
    description "Histidine"
    name "HIP", "HSP"
    code 'H'
    type :protein
    spec "{backbone}-CB-CG%1=CD2-[NE2H+]=CE1-ND1-%1"
  end

  ResidueTemplate.register do
    description "Isoleucine"
    name "ILE"
    code 'I'
    type :protein
    spec "{backbone}-CB(-CG1-CD1)-CG2"
  end

  ResidueTemplate.register do
    description "Leucine"
    name "LEU"
    code 'L'
    type :protein
    spec "{backbone}-CB-CG(-CD1)-CD2"
    symmetry({"CD1", "CD2"})
  end

  ResidueTemplate.register do
    description "Lysine"
    name "LYS"
    code 'K'
    type :protein
    spec "{backbone}-CB-CG-CD-CE-[NZH3+]"
  end

  ResidueTemplate.register do
    description "Methionine "
    name "MET"
    code 'M'
    type :protein
    spec "{backbone}-CB-CG-SD-CE"
  end

  ResidueTemplate.register do
    description "Phenylalanine"
    name "PHE"
    code 'F'
    type :protein
    spec "{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1"
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  ResidueTemplate.register do
    description "Proline"
    name "PRO"
    code 'P'
    type :protein
    spec "N%1-CA(-C=O)-CB-CG-CD-%1"
  end

  ResidueTemplate.register do
    description "Serine"
    name "SER"
    code 'S'
    type :protein
    spec "{backbone}-CB-OG"
  end

  ResidueTemplate.register do
    description "Threonine"
    name "THR"
    code 'T'
    type :protein
    spec "{backbone}-CB(-OG1)-CG2"
  end

  ResidueTemplate.register do
    description "Tryptophan"
    name "TRP"
    code 'W'
    type :protein
    spec "{backbone}-CB-CG%1=CD1-NE1-CE2(-CZ2=CH2-CZ3=CE3-CD2%2)=%2-%1"
  end

  ResidueTemplate.register do
    description "Tyrosine"
    name "TYR"
    code 'Y'
    type :protein
    spec "{backbone}-CB-CG%1=CD1-CE1=CZ(-OH)-CE2=CD2-%1"
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  ResidueTemplate.register do
    description "Valine"
    name "VAL"
    code 'V'
    type :protein
    spec "{backbone}-CB(-CG1)-CG2"
    symmetry({"CG1", "CG2"})
  end
end
