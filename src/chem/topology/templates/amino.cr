require "../templates"

module Chem::Topology::Templates
  aminoacid do
    name "Alanine"
    code "ALA"
    symbol 'A'
    sidechain "CB"
  end

  aminoacid do
    name "Arginine"
    code "ARG"
    symbol 'R'
    sidechain do
      main "CB-CG-CD-NE-CZ=NH1"
      branch "CZ-NH2"
    end
  end

  aminoacid do
    name "Aspartate"
    code "ASH"
    symbol 'D'
    sidechain do
      main "CB-CG=OD1"
      branch "CG-OD2"
    end
  end

  aminoacid do
    name "Asparagine"
    code "ASN"
    symbol 'N'
    sidechain do
      main "CB-CG-ND2"
      branch "CG=OD1"
    end
  end

  aminoacid do
    name "Aspartate"
    code "ASP"
    symbol 'D'
    sidechain do
      main "CB-CG=OD1"
      branch "CG-OD2-"
    end
  end

  aminoacid do
    name "Cysteine"
    code "CYS"
    symbol 'C'
    sidechain "CB-SG"
  end

  aminoacid do
    name "Cysteine"
    code "CYX"
    symbol 'C'
    sidechain "CB-SG(1)"
  end

  aminoacid do
    name "Glutamate"
    code "GLH"
    symbol 'E'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-OE2"
    end
  end

  aminoacid do
    name "Glutamine"
    code "GLN"
    symbol 'Q'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-NE2"
    end
  end

  aminoacid do
    name "Glutamate"
    code "GLU"
    symbol 'E'
    sidechain do
      main "CB-CG-CD=OE1"
      branch "CD-OE2-"
    end
  end

  aminoacid do
    name "Glycine"
    code "GLY"
    symbol 'G'
    remove_atom "HA"
  end

  aminoacid do
    name "Histidine"
    code "HIS"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2=CE1-ND1"
    end
  end

  aminoacid do
    name "Histidine"
    code "HIE"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2-CE1=ND1"
    end
  end

  aminoacid do
    name "Histidine"
    code "HIP"
    symbol 'H'
    sidechain do
      main "CB-CG"
      cycle "CG=CD2-NE2+=CE1-ND1"
    end
  end

  aminoacid do
    name "Isoleucine"
    code "ILE"
    symbol 'I'
    sidechain do
      main "CB-CG1-CD"
      branch "CB-CG2"
    end
  end

  aminoacid do
    name "Leucine"
    code "LEU"
    symbol 'L'
    sidechain do
      main "CB-CG-CD1"
      branch "CG-CD2"
    end
  end

  aminoacid do
    name "Lysine"
    code "LYS"
    symbol 'K'
    sidechain "CB-CG-CD-CE-NZ+"
  end

  aminoacid do
    name "Methionine "
    code "MET"
    symbol 'M'
    sidechain "CB-CG-SD-CE"
  end

  aminoacid do
    name "Phenylalanine"
    code "PHE"
    symbol 'F'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-CE1=CZ-CE2=CD2"
    end
  end

  aminoacid do
    name "Proline"
    code "PRO"
    symbol 'P'

    remove_atom "H"
    sidechain do
      cycle "CA-CB-CG-CD-N"
    end
  end

  aminoacid do
    name "Serine"
    code "SER"
    symbol 'S'
    sidechain "CB-OG"
  end

  aminoacid do
    name "Threonine"
    code "THR"
    symbol 'T'
    sidechain do
      main "CB-OG1"
      branch "CB-CG2"
    end
  end

  aminoacid do
    name "Tryptophan"
    code "TRP"
    symbol 'W'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-NE1-CE2=CD2"
      cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
    end
  end

  aminoacid do
    name "Tyrosine"
    code "TYR"
    symbol 'Y'
    sidechain do
      main "CB-CG"
      cycle "CG=CD1-CE1=CZ-CE2=CD2"
      branch "CZ-OH"
    end
  end

  aminoacid do
    name "Valine"
    code "VAL"
    symbol 'V'
    sidechain do
      main "CB-CG1"
      branch "CB-CG2"
    end
  end
end
