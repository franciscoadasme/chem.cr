module Chem::Topology::Templates
  aminoacid do
    description "Alanine"
    name "ALA"
    code 'A'
    structure do
      backbone
      sidechain "CB"
    end
  end

  aminoacid do
    description "Arginine"
    name "ARG"
    code 'R'
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD-NE-CZ=NH1+"
        branch "CZ-NH2"
      end
    end
  end

  aminoacid do
    description "Aspartate"
    name "ASH"
    code 'D'
    structure do
      backbone
      sidechain do
        stem "CB-CG=OD1"
        branch "CG-OD2"
      end
    end
  end

  aminoacid do
    description "Asparagine"
    name "ASN"
    code 'N'
    structure do
      backbone
      sidechain do
        stem "CB-CG-ND2"
        branch "CG=OD1"
      end
    end
  end

  aminoacid do
    description "Aspartate"
    name "ASP"
    code 'D'
    structure do
      backbone
      sidechain do
        stem "CB-CG=OD1"
        branch "CG-OD2-"
      end
    end
  end

  aminoacid do
    description "Cysteine"
    name "CYS"
    code 'C'
    structure do
      backbone
      sidechain "CB-SG(2)"
    end
  end

  aminoacid do
    description "Cysteine"
    name "CYX"
    code 'C'
    structure do
      backbone
      sidechain "CB-SG(1)"
    end
  end

  aminoacid do
    description "Glutamate"
    name "GLH"
    code 'E'
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-OE2"
      end
    end
  end

  aminoacid do
    description "Glutamine"
    name "GLN"
    code 'Q'
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-NE2"
      end
    end
  end

  aminoacid do
    description "Glutamate"
    name "GLU"
    code 'E'
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-OE2-"
      end
    end
  end

  aminoacid do
    description "Glycine"
    name "GLY"
    code 'G'
    structure do
      backbone
      remove_atom "HA"
    end
  end

  aminoacid do
    description "Histidine"
    name "HIS"
    code 'H'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2=CE1-ND1"
      end
    end
  end

  aminoacid do
    description "Histidine"
    name "HIE"
    code 'H'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2-CE1=ND1"
      end
    end
  end

  aminoacid do
    description "Histidine"
    name "HIP"
    code 'H'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2+=CE1-ND1"
      end
    end
  end

  aminoacid do
    description "Isoleucine"
    name "ILE"
    code 'I'
    structure do
      backbone
      sidechain do
        stem "CB-CG1-CD1"
        branch "CB-CG2"
      end
    end
  end

  aminoacid do
    description "Leucine"
    name "LEU"
    code 'L'
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD1"
        branch "CG-CD2"
      end
    end
  end

  aminoacid do
    description "Lysine"
    name "LYS"
    code 'K'
    structure do
      backbone
      sidechain "CB-CG-CD-CE-NZ+"
    end
  end

  aminoacid do
    description "Methionine "
    name "MET"
    code 'M'
    structure do
      backbone
      sidechain "CB-CG-SD(2)-CE"
    end
  end

  aminoacid do
    description "Phenylalanine"
    name "PHE"
    code 'F'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-CE1=CZ-CE2=CD2"
      end
    end
  end

  aminoacid do
    description "Proline"
    name "PRO"
    code 'P'

    structure do
      backbone
      remove_atom "H"
      sidechain do
        cycle "CA-CB-CG-CD-N"
      end
    end
  end

  aminoacid do
    description "Serine"
    name "SER"
    code 'S'
    structure do
      backbone
      sidechain "CB-OG"
    end
  end

  aminoacid do
    description "Threonine"
    name "THR"
    code 'T'
    structure do
      backbone
      sidechain do
        stem "CB-OG1"
        branch "CB-CG2"
      end
    end
  end

  aminoacid do
    description "Tryptophan"
    name "TRP"
    code 'W'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-NE1-CE2=CD2"
        cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
      end
    end
  end

  aminoacid do
    description "Tyrosine"
    name "TYR"
    code 'Y'
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-CE1=CZ-CE2=CD2"
        branch "CZ-OH"
      end
    end
  end

  aminoacid do
    description "Valine"
    name "VAL"
    code 'V'
    structure do
      backbone
      sidechain do
        stem "CB-CG1"
        branch "CB-CG2"
      end
    end
  end
end
