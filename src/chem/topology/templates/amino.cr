module Chem::Topology::Templates
  register_type do
    description "Alanine"
    name "ALA"
    code 'A'
    kind :protein
    structure do
      backbone
      sidechain "CB"
    end
  end

  register_type do
    description "Arginine"
    name "ARG"
    code 'R'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD-NE-CZ=NH1+"
        branch "CZ-NH2"
      end
    end
  end

  register_type do
    description "Aspartate"
    name "ASH"
    code 'D'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG=OD1"
        branch "CG-OD2"
      end
    end
  end

  register_type do
    description "Asparagine"
    name "ASN"
    code 'N'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-ND2"
        branch "CG=OD1"
      end
    end
  end

  register_type do
    description "Aspartate"
    name "ASP"
    code 'D'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG=OD1"
        branch "CG-OD2-"
      end
    end
  end

  register_type do
    description "Cysteine"
    name "CYS"
    code 'C'
    kind :protein
    structure do
      backbone
      sidechain "CB-SG(2)"
    end
  end

  register_type do
    description "Cysteine"
    name "CYX"
    code 'C'
    kind :protein
    structure do
      backbone
      sidechain "CB-SG(1)"
    end
  end

  register_type do
    description "Glutamate"
    name "GLH"
    code 'E'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-OE2"
      end
    end
  end

  register_type do
    description "Glutamine"
    name "GLN"
    code 'Q'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-NE2"
      end
    end
  end

  register_type do
    description "Glutamate"
    name "GLU"
    code 'E'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD=OE1"
        branch "CD-OE2-"
      end
    end
  end

  register_type do
    description "Glycine"
    name "GLY"
    code 'G'
    kind :protein
    structure do
      backbone
      remove_atom "HA"
    end
  end

  register_type do
    description "Histidine"
    name "HIS"
    code 'H'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2=CE1-ND1"
      end
    end
  end

  register_type do
    description "Histidine"
    name "HIE"
    code 'H'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2-CE1=ND1"
      end
    end
  end

  register_type do
    description "Histidine"
    name "HIP"
    code 'H'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD2-NE2+=CE1-ND1"
      end
    end
  end

  register_type do
    description "Isoleucine"
    name "ILE"
    code 'I'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG1-CD1"
        branch "CB-CG2"
      end
    end
  end

  register_type do
    description "Leucine"
    name "LEU"
    code 'L'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG-CD1"
        branch "CG-CD2"
      end
    end
    symmetry({"CD1", "CD2"})
  end

  register_type do
    description "Lysine"
    name "LYS"
    code 'K'
    kind :protein
    structure do
      backbone
      sidechain "CB-CG-CD-CE-NZ+"
    end
  end

  register_type do
    description "Methionine "
    name "MET"
    code 'M'
    kind :protein
    structure do
      backbone
      sidechain "CB-CG-SD(2)-CE"
    end
  end

  register_type do
    description "Phenylalanine"
    name "PHE"
    code 'F'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-CE1=CZ-CE2=CD2"
      end
    end
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  register_type do
    description "Proline"
    name "PRO"
    code 'P'
    kind :protein

    structure do
      backbone
      remove_atom "H"
      sidechain do
        cycle "CA-CB-CG-CD-N"
      end
    end
  end

  register_type do
    description "Serine"
    name "SER"
    code 'S'
    kind :protein
    structure do
      backbone
      sidechain "CB-OG"
    end
  end

  register_type do
    description "Threonine"
    name "THR"
    code 'T'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-OG1"
        branch "CB-CG2"
      end
    end
  end

  register_type do
    description "Tryptophan"
    name "TRP"
    code 'W'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-NE1-CE2=CD2"
        cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
      end
    end
  end

  register_type do
    description "Tyrosine"
    name "TYR"
    code 'Y'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG"
        cycle "CG=CD1-CE1=CZ-CE2=CD2"
        branch "CZ-OH"
      end
    end
    symmetry({"CD1", "CD2"}, {"CE1", "CE2"})
  end

  register_type do
    description "Valine"
    name "VAL"
    code 'V'
    kind :protein
    structure do
      backbone
      sidechain do
        stem "CB-CG1"
        branch "CB-CG2"
      end
    end
    symmetry({"CG1", "CG2"})
  end
end
