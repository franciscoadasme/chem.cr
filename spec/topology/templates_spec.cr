require "../spec_helper"

require "../../src/chem/topology/templates/amino"

alias TemplateBuilder = Chem::Topology::Templates::Builder
alias TemplateError = Chem::Topology::Templates::Error

describe Chem::Topology::Templates::Builder do
  describe ".build" do
    bb_names = ["N", "H", "CA", "HA", "C", "O"]

    it "builds a residue without sidechain" do
      residue = TemplateBuilder.build do
        name "Glycine"
        code "Gly"
        symbol 'G'

        backbone
        remove_atom "HA"
      end

      residue.atom_names.should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
      residue.bonds.size.should eq 6 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a residue with short sidechain" do
      residue = TemplateBuilder.build do
        name "Alanine"
        code "ALA"
        symbol 'A'
        backbone
        sidechain "CB"
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
      residue.bonds.size.should eq 9 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a residue with branched sidechain" do
      residue = TemplateBuilder.build do
        name "Isoleucine"
        code "ILE"
        symbol 'I'
        backbone
        sidechain do
          main "CB-CG1-CD1"
          branch "CB-CG2"
        end
      end

      names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                          "HD13", "CG2", "HG21", "HG22", "HG23"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 18 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a positively charged residue" do
      residue = TemplateBuilder.build do
        name "Lysine"
        code "LYS"
        symbol 'K'
        backbone
        sidechain "CB-CG-CD-CE-NZ+"
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                          "CE", "HE1", "HE2", "NZ", "HZ1", "HZ2", "HZ3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 21 + 2
      residue.formal_charge.should eq 1
    end

    it "builds a negatively charged residue" do
      residue = TemplateBuilder.build do
        name "Aspartate"
        code "ASP"
        symbol 'D'
        backbone
        sidechain do
          main "CB-CG=OE1"
          branch "CG-OE2-"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "OE1", "OE2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 11 + 2
      residue.formal_charge.should eq -1
    end

    it "builds a positively charged residue with one branch in the sidechain" do
      residue = TemplateBuilder.build do
        name "Arginine"
        code "ARG"
        symbol 'R'
        backbone
        sidechain do
          main "CB-CG-CD-NE-CZ-NH1"
          branch "CZ=NH2+"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                          "NE", "HE", "CZ", "NH1", "HH11", "HH12", "NH2", "HH21",
                          "HH22"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 23 + 2
      residue.formal_charge.should eq 1
    end

    it "builds a residue with a cyclic sidechain" do
      residue = TemplateBuilder.build do
        name "Histidine"
        code "HIS"
        symbol 'H'

        backbone
        sidechain do
          main "CB-CG"
          cycle "CG=CD2-NE2=CE1-ND1"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                          "ND1", "HD1"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a cyclic sidechain with terminal bond" do
      residue = TemplateBuilder.build do
        name "Histidine"
        code "HIS"
        symbol 'H'

        backbone
        sidechain do
          main "CB-CG"
          cycle "CG-ND1-CE1=NE2-CD2="
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "ND1", "HD1", "CE1", "HE1", "NE2",
                          "CD2", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a bicyclic sidechain" do
      residue = TemplateBuilder.build do
        name "Tryptophan"
        code "TRP"
        symbol 'W'

        backbone
        sidechain do
          main "CB-CG"
          cycle "CG=CD1-NE1-CE2=CD2"
          cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                          "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 25 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a cyclic residue" do
      residue = TemplateBuilder.build do
        name "Proline"
        code "PRO"
        symbol 'P'

        backbone
        remove_atom "H"
        sidechain do
          cycle "CA-CB-CG-CD-N"
        end
      end

      names = ["N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
               "HD1", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 14 + 2
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valence" do
      residue = TemplateBuilder.build do
        name "Cysteine"
        code "CYX"
        symbol 'C'

        backbone
        sidechain "CB-SG(1)"
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "SG"]
      residue.bonds.size.should eq 9 + 2
      residue.formal_charge.should eq 0
    end

    it "fails when adding the same bond twice with different order" do
      # #cycle connects the first and last atoms with a single bond unless there is a
      # bond char (-, =, # or @) at the end. In this case, both CE2=CD2 and CD2-CE2 are
      # added
      expect_raises TemplateError, "bond CD2-CE2 already exists" do
        TemplateBuilder.build do
          name "Tryptophan"
          code "TRP"
          symbol 'W'

          main "CB-CG"
          cycle "CG=CD1-NE1-CE2=CD2"
          cycle "CE2-CZ2=CH2-CZ3=CE3-CD2"
        end
      end
    end

    it "fails on incorrect valence" do
      expect_raises TemplateError, "incorrect valence" do
        TemplateBuilder.build do
          name "Tryptophan"
          code "TRP"
          symbol 'W'

          main "CB-CG=CD"
          branch "CG-CZ"
          branch "CG-OTX-"
        end
      end
    end

    it "fails when adding a branch without existing root" do
      expect_raises TemplateError, "branch must start with an existing atom name" do
        TemplateBuilder.build { branch "CB-CG2" }
      end
    end

    it "fails when adding sidechain without backbone" do
      expect_raises TemplateError, "missing backbone" do
        TemplateBuilder.build { sidechain "CB-CG" }
      end
    end
  end
end
