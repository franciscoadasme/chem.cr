module Chem::Topology::Templates
  aminoacid do
    description "Alanine"
    name "ALA"
    symbol 'A'
    sidechain "CB"
  end

  aminoacid do
    description "Arginine"
    name "ARG"
    symbol 'R'
    sidechain do
      main "CB-CG-CD-NE-CZ=NH1"
      branch "CZ-NH2"
    end
  end

  aminoacid do
    description "Aspartate"
    name "ASH"
    symbol 'D'
    sidechain do
      main "CB-CG=OD1"
      branch "CG-OD2"
    end
  end

  aminoacid do
    description "Asparagine"
    name "ASN"
    symbol 'N'
    sidechain do
      main "CB-CG-ND2"
      branch "CG=OD1"
    end
  end

  aminoacid do
    description "Aspartate"
    name "ASP"
    symbol 'D'
    sidechain do
      main "CB-CG=OD1"
      branch "CG-OD2-"
    end
  end

  aminoacid do
    description "Cysteine"
    name "CYS"
    symbol 'C'
    sidechain "CB-SG"
  end

  aminoacid do
    description "Cysteine"
    name "CYX"
    symbol 'C'
    sidechain "CB-SG(1)"
  end

  aminoacid do
    description "Glutamate"
    name "GLH"
    symbol 'E'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-OE2"
    end
  end

  aminoacid do
    description "Glutamine"
    name "GLN"
    symbol 'Q'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-NE2"
    end
  end

  aminoacid do
    description "Glutamate"
    name "GLU"
    symbol 'E'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-OE2-"
    end
  end

  aminoacid do
    description "Glycine"
    name "GLY"
    symbol 'G'
    remove_atom "HA"
  end

  aminoacid do
    description "Histidine"
    name "HIS"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2=CE1-ND1"
    end
  end

  aminoacid do
    description "Histidine"
    name "HIE"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2-CE1=ND1"
    end
  end

  aminoacid do
    description "Histidine"
    name "HIP"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2+=CE1-ND1"
    end
  end

  aminoacid do
    description "Isoleucine"
    name "ILE"
    symbol 'I'
    sidechain do
      main "CB-CG1-CD"
      branch "CB-CG2"
    end
  end

  aminoacid do
    description "Leucine"
    name "LEU"
    symbol 'L'
    sidechain do
      main "CB-CG-CD1"
      branch "CG-CD2"
    end
  end

  aminoacid do
    description "Lysine"
    name "LYS"
    symbol 'K'
    sidechain "CB-CG-CD-CE-NZ+"
  end

  aminoacid do
    description "Methionine "
    name "MET"
    symbol 'M'
    sidechain "CB-CG-SD-CE"
  end

  aminoacid do
    description "Phenylalanine"
    name "PHE"
    symbol 'F'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-CE1=CZ-CE2=CD2"
    end
  end

  aminoacid do
    description "Proline"
    name "PRO"
    symbol 'P'

    remove_atom "H"
    sidechain do
      cycle "CA-CB-CG-CD-N"
    end
  end

  aminoacid do
    description "Serine"
    name "SER"
    symbol 'S'
    sidechain "CB-OG"
  end

  aminoacid do
    description "Threonine"
    name "THR"
    symbol 'T'
    sidechain do
      main "CB-OG1"
      branch "CB-CG2"
    end
  end

  aminoacid do
    description "Tryptophan"
    name "TRP"
    symbol 'W'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-NE1-CE2=CD2"
      cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
    end
  end

  aminoacid do
    description "Tyrosine"
    name "TYR"
    symbol 'Y'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-CE1=CZ-CE2=CD2"
      branch "CZ-OH"
    end
  end

  aminoacid do
    description "Valine"
    name "VAL"
    symbol 'V'
    sidechain do
      main "CB-CG1"
      branch "CB-CG2"
    end
  end
end
