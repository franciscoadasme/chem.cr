require "../spec_helper"

alias Templates = Chem::Topology::Templates
alias TemplateBuilder = Chem::Topology::Templates::Builder
alias TemplateError = Chem::Topology::Templates::Error

describe Chem::Topology::Templates::AtomType do
  describe "#to_s" do
    it "returns atom name" do
      Templates::AtomType.new("CA").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Templates::AtomType.new("NZ", formal_charge: 1).to_s.should eq "NZ+"
      Templates::AtomType.new("OE1", formal_charge: -1).to_s.should eq "OE1-"
      Templates::AtomType.new("NA", formal_charge: 2).to_s.should eq "NA+2"
      Templates::AtomType.new("UK", formal_charge: -5).to_s.should eq "UK-5"
    end

    it "returns atom name plus valency when its not nominal" do
      Templates::AtomType.new("SG", valency: 1).to_s.should eq "SG(1)"
    end
  end
end

describe Chem::Topology::Templates::Builder do
  describe ".build" do
    bb_names = ["N", "H", "CA", "HA", "C", "O"]

    it "builds a residue without sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Glycine"
        name "Gly"
        symbol 'G'
        remove_atom "HA"
      end

      residue.atom_names.should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
      residue.bonds.size.should eq 6
      residue.formal_charge.should eq 0
    end

    it "builds a residue with short sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Alanine"
        name "ALA"
        symbol 'A'
        sidechain "CB"
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue with branched sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Isoleucine"
        name "ILE"
        symbol 'I'
        sidechain do
          main "CB-CG1-CD1"
          branch "CB-CG2"
        end
      end

      names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                          "HD13", "CG2", "HG21", "HG22", "HG23"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 18
      residue.formal_charge.should eq 0
    end

    it "builds a positively charged residue" do
      residue = TemplateBuilder.build(:protein) do
        description "Lysine"
        name "LYS"
        symbol 'K'
        sidechain "CB-CG-CD-CE-NZ+"
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                          "CE", "HE1", "HE2", "NZ", "HZ1", "HZ2", "HZ3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 21
      residue.formal_charge.should eq 1
    end

    it "builds a negatively charged residue" do
      residue = TemplateBuilder.build(:protein) do
        description "Aspartate"
        name "ASP"
        symbol 'D'
        sidechain do
          main "CB-CG=OE1"
          branch "CG-OE2-"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "OE1", "OE2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 11
      residue.formal_charge.should eq -1
    end

    it "builds a residue with charge +2" do
      residue = TemplateBuilder.build(:ion) do
        description "Magnesium"
        name "MG"
        main "MG+2"
      end

      residue.formal_charge.should eq 2
    end

    it "builds a positively charged residue with one branch in the sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Arginine"
        name "ARG"
        symbol 'R'
        sidechain do
          main "CB-CG-CD-NE-CZ-NH1"
          branch "CZ=NH2+"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                          "NE", "HE", "CZ", "NH1", "HH11", "HH12", "NH2", "HH21",
                          "HH22"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 23
      residue.formal_charge.should eq 1
    end

    it "builds a residue with a cyclic sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Histidine"
        name "HIS"
        symbol 'H'
        sidechain do
          main "CB-CG"
          cycle "CG=CD2-NE2=CE1-ND1"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                          "ND1", "HD1"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a cyclic sidechain with terminal bond" do
      residue = TemplateBuilder.build(:protein) do
        description "Histidine"
        name "HIS"
        symbol 'H'
        sidechain do
          main "CB-CG"
          cycle "CG-ND1-CE1=NE2-CD2="
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "ND1", "HD1", "CE1", "HE1", "NE2",
                          "CD2", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a bicyclic sidechain" do
      residue = TemplateBuilder.build(:protein) do
        description "Tryptophan"
        name "TRP"
        symbol 'W'
        sidechain do
          main "CB-CG"
          cycle "CG=CD1-NE1-CE2=CD2"
          cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                          "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 25
      residue.formal_charge.should eq 0
    end

    it "builds a cyclic residue" do
      residue = TemplateBuilder.build(:protein) do
        description "Proline"
        name "PRO"
        symbol 'P'
        remove_atom "H"
        sidechain do
          cycle "CA-CB-CG-CD-N"
        end
      end

      names = ["N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
               "HD1", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 14
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency" do
      residue = TemplateBuilder.build(:protein) do
        description "Cysteine"
        name "CYX"
        symbol 'C'
        sidechain "CB-SG(1)"
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "SG"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency followed by a bond" do
      residue = TemplateBuilder.build(:ion) do
        description "Sulfate"
        name "SO4"
        main "S(2)=O1"
      end

      residue.atom_names.should eq ["S", "O1"]
      residue.atom_types.map(&.valency).should eq [2, 2]
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit element" do
      residue = TemplateBuilder.build(:ion) do
        description "Calcium"
        name "CA"
        main "CA[Ca]"
      end
      residue.atom_types[0].element.should eq PeriodicTable::Ca
    end

    it "builds a polymer residue" do
      residue_t = TemplateBuilder.build(:other) do
        description "Fake"
        name "UNK"
        main "C1-C2-C3"
        link_adjacent_by "C3=C1"
      end

      residue_t.atom_names.should eq ["C1", "H1", "C2", "H2", "H3", "C3", "H4"]
      residue_t.bonds.size.should eq 6
      residue_t.monomer?.should be_true
      residue_t.link_bond.should eq Templates::Bond.new("C3", "C1", 2)
    end

    it "builds a rooted residue" do
      residue_t = TemplateBuilder.build(:other) do
        description "Fake"
        name "UNK"
        main "C1=C2"
        root "C2"
      end

      residue_t.atom_names.should eq ["C1", "H1", "H2", "C2", "H3", "H4"]
      residue_t.bonds.size.should eq 5
      residue_t.root.should eq residue_t["C2"]
    end

    it "builds a residue with numbered atoms per element" do
      residue = TemplateBuilder.build(:solvent) do
        description "Glycerol"
        name "GOL"
        main "O1-C1-C2-C3-O3"
        branch "C2-O2"
      end

      names = ["O1", "H1", "C1", "H4", "H5", "C2", "H6", "C3", "H7", "H8", "O3", "H3",
               "O2", "H2"]
      residue.atom_names.should eq names
    end

    it "builds a residue with three-letter atom names" do
      residue = TemplateBuilder.build(:other) do
        description "C-ter"
        name "CTER"
        main "CA-C=O"
        branch "C-OXT"
      end

      residue.atom_names.should eq ["CA", "HA1", "HA2", "HA3", "C", "O", "OXT", "HXT"]
    end

    it "fails when adding the same bond twice with different order" do
      # #cycle connects the first and last atoms with a single bond unless there is a
      # bond char (-, =, # or @) at the end. In this case, both CE2=CD2 and CD2-CE2 are
      # added
      expect_raises TemplateError, "Bond CD2=CE2 already exists" do
        TemplateBuilder.build(:protein) do
          description "Tryptophan"
          name "TRP"
          symbol 'W'

          main "CB-CG"
          cycle "CG=CD1-NE1-CE2=CD2"
          cycle "CE2-CZ2=CH2-CZ3=CE3-CD2"
        end
      end
    end

    it "fails on incorrect valency" do
      msg = "Atom type CG has incorrect valency (5), expected 4"
      expect_raises TemplateError, msg do
        TemplateBuilder.build(:protein) do
          description "Tryptophan"
          name "TRP"
          symbol 'W'

          main "CB-CG=CD"
          branch "CG-CZ"
          branch "CG-OTX-"
        end
      end
    end

    it "fails when adding a branch without existing root" do
      msg = "Branch must start with an existing atom type, got CB"
      expect_raises TemplateError, msg do
        TemplateBuilder.build(:protein) { branch "CB-CG2" }
      end
    end
  end
end

describe Chem::Topology::Templates do
  Templates.residue do
    description "Anything"
    name "LFG"
    main "N1+-C2-C3-O4-C5-C6"
    branch "C5=O7"
  end

  describe "#[]" do
    it "returns a residue template by name" do
      residue_t = Templates["LFG"]
      residue_t.should be_a Templates::ResidueType
      residue_t.description.should eq "Anything"
      residue_t.name.should eq "LFG"
    end

    it "fails when no matching residue template exists" do
      expect_raises TemplateError, "Unknown residue template" do
        Templates["ASD"]
      end
    end
  end

  describe "#[]?" do
    it "returns a residue template by name" do
      Templates["LFG"].should be_a Templates::ResidueType
    end

    it "returns nil when no matching residue template exists" do
      Templates["ASD"]?.should be_nil
    end
  end

  describe "#residue" do
    it "creates a residue template with multiple names" do
      Templates.residue do
        description "Anything"
        names "LXE", "EGR"
        main "C1"
      end
      Templates["LXE"].should be Templates["EGR"]
    end

    it "fails when the residue name already exists" do
      expect_raises TemplateError, "Duplicate residue template" do
        Templates.residue do
          description "Anything"
          name "LXE"
          main "C1"
        end
      end
    end
  end
end
