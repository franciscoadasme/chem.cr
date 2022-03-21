require "../spec_helper"

describe Chem::Topology::Templates::Builder do
  describe ".build" do
    bb_names = ["N", "H", "CA", "HA", "C", "O"]

    it "builds a residue without sidechain" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Glycine"
        name "Gly"
        code 'G'
        structure do
          remove_atom "HA"
        end
      end

      residue.atom_names.should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
      residue.bonds.size.should eq 6
      residue.formal_charge.should eq 0
    end

    it "builds a residue with short sidechain" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Alanine"
        name "ALA"
        code 'A'
        structure do
          sidechain "CB"
        end
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue with branched sidechain" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Isoleucine"
        name "ILE"
        code 'I'
        structure do
          sidechain do
            stem "CB-CG1-CD1"
            branch "CB-CG2"
          end
        end
      end

      names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                          "HD13", "CG2", "HG21", "HG22", "HG23"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 18
      residue.formal_charge.should eq 0
    end

    it "builds a positively charged residue" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Lysine"
        name "LYS"
        code 'K'
        structure do
          sidechain "CB-CG-CD-CE-NZ+"
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                          "CE", "HE1", "HE2", "NZ", "HZ1", "HZ2", "HZ3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 21
      residue.formal_charge.should eq 1
    end

    it "builds a negatively charged residue" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Aspartate"
        name "ASP"
        code 'D'
        structure do
          sidechain do
            stem "CB-CG=OE1"
            branch "CG-OE2-"
          end
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "OE1", "OE2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 11
      residue.formal_charge.should eq -1
    end

    it "builds a residue with charge +2" do
      residue = Chem::Topology::ResidueType.build(:ion) do
        description "Magnesium"
        name "MG"
        structure do
          stem "MG+2"
        end
      end

      residue.formal_charge.should eq 2
    end

    it "builds a positively charged residue with one branch in the sidechain" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Arginine"
        name "ARG"
        code 'R'
        structure do
          sidechain do
            stem "CB-CG-CD-NE-CZ-NH1"
            branch "CZ=NH2+"
          end
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
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Histidine"
        name "HIS"
        code 'H'
        structure do
          sidechain do
            stem "CB-CG"
            cycle "CG=CD2-NE2=CE1-ND1"
          end
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                          "ND1", "HD1"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a cyclic sidechain with terminal bond" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Histidine"
        name "HIS"
        code 'H'
        structure do
          sidechain do
            stem "CB-CG"
            cycle "CG-ND1-CE1=NE2-CD2="
          end
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "ND1", "HD1", "CE1", "HE1", "NE2",
                          "CD2", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a bicyclic sidechain" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Tryptophan"
        name "TRP"
        code 'W'
        structure do
          sidechain do
            stem "CB-CG"
            cycle "CG=CD1-NE1-CE2=CD2"
            cycle "CE2-CZ2=CH2-CZ3=CE3-CD2="
          end
        end
      end

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                          "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 25
      residue.formal_charge.should eq 0
    end

    it "builds a cyclic residue" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Proline"
        name "PRO"
        code 'P'
        structure do
          remove_atom "H"
          sidechain do
            cycle "CA-CB-CG-CD-N"
          end
        end
      end

      names = ["N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
               "HD1", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 14
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency" do
      residue = Chem::Topology::ResidueType.build(:protein) do
        description "Cysteine"
        name "CYX"
        code 'C'
        structure do
          sidechain "CB-SG(1)"
        end
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "SG"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency followed by a bond" do
      residue = Chem::Topology::ResidueType.build(:ion) do
        description "Sulfate"
        name "SO4"
        structure "S(2)=O1"
      end

      residue.atom_names.should eq ["S", "O1"]
      residue.atom_types.map(&.valency).should eq [2, 2]
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit element" do
      residue = Chem::Topology::ResidueType.build(:ion) do
        description "Calcium"
        name "CA"
        structure "CA[Ca]"
      end
      residue.atom_types[0].element.should eq Chem::PeriodicTable::Ca
    end

    it "builds a polymer residue" do
      residue_t = Chem::Topology::ResidueType.build(:other) do
        description "Fake"
        name "UNK"
        structure "C1-C2-C3"
        link_adjacent_by "C3=C1"
      end

      residue_t.atom_names.should eq ["C1", "H1", "C2", "H2", "H3", "C3", "H4"]
      residue_t.bonds.size.should eq 6
      residue_t.monomer?.should be_true

      bond_t = residue_t.link_bond.should_not be_nil
      bond_t[0].name.should eq "C3"
      bond_t[1].name.should eq "C1"
      bond_t.order.should eq 2
    end

    it "builds a rooted residue" do
      residue_t = Chem::Topology::ResidueType.build(:other) do
        description "Fake"
        name "UNK"
        structure "C1=C2"
        root "C2"
      end

      residue_t.atom_names.should eq ["C1", "H1", "H2", "C2", "H3", "H4"]
      residue_t.bonds.size.should eq 5
      residue_t.root.should eq residue_t["C2"]
    end

    it "builds a residue with numbered atoms per element" do
      residue = Chem::Topology::ResidueType.build(:solvent) do
        description "Glycerol"
        name "GOL"
        structure do
          stem "O1-C1-C2-C3-O3"
          branch "C2-O2"
        end
      end

      names = ["O1", "H1", "C1", "H4", "H5", "C2", "H6", "C3", "H7", "H8", "O3", "H3",
               "O2", "H2"]
      residue.atom_names.should eq names
    end

    it "builds a residue with three-letter atom names" do
      residue = Chem::Topology::ResidueType.build(:other) do
        description "C-ter"
        name "CTER"
        structure do
          stem "CA-C=O"
          branch "C-OXT"
        end
      end

      residue.atom_names.should eq ["CA", "HA1", "HA2", "HA3", "C", "O", "OXT", "HXT"]
    end

    it "fails when adding the same bond twice with different order" do
      # #cycle connects the first and last atoms with a single bond unless there is a
      # bond char (-, =, # or @) at the end. In this case, both CE2=CD2 and CD2-CE2 are
      # added
      expect_raises Chem::Topology::Templates::Error, "Bond CD2=CE2 already exists" do
        Chem::Topology::ResidueType.build(:protein) do
          description "Tryptophan"
          name "TRP"
          code 'W'

          structure do
            stem "CB-CG"
            cycle "CG=CD1-NE1-CE2=CD2"
            cycle "CE2-CZ2=CH2-CZ3=CE3-CD2"
          end
        end
      end
    end

    it "fails on incorrect valency" do
      msg = "Atom type CG has incorrect valency (5), expected 4"
      expect_raises Chem::Topology::Templates::Error, msg do
        Chem::Topology::ResidueType.build(:protein) do
          description "Tryptophan"
          name "TRP"
          code 'W'

          structure do
            stem "CB-CG=CD"
            branch "CG-CZ"
            branch "CG-OTX-"
          end
        end
      end
    end

    it "fails when adding a branch without existing root" do
      msg = "Branch must start with an existing atom type, got CB"
      expect_raises Chem::Topology::Templates::Error, msg do
        Chem::Topology::ResidueType.build(:protein) do
          structure do
            branch "CB-CG2"
          end
        end
      end
    end
  end
end

describe Chem::Topology::Templates do
  Chem::Topology::Templates.residue do
    description "Anything"
    name "LFG"
    structure do
      stem "N1+-C2-C3-O4-C5-C6"
      branch "C5=O7"
    end
  end

  describe "#[]" do
    it "returns a residue template by name" do
      residue_t = Chem::Topology::Templates["LFG"]
      residue_t.should be_a Chem::Topology::ResidueType
      residue_t.description.should eq "Anything"
      residue_t.name.should eq "LFG"
    end

    it "fails when no matching residue template exists" do
      expect_raises Chem::Topology::Templates::Error, "Unknown residue template" do
        Chem::Topology::Templates["ASD"]
      end
    end
  end

  describe "#[]?" do
    it "returns a residue template by name" do
      Chem::Topology::Templates["LFG"].should be_a Chem::Topology::ResidueType
    end

    it "returns nil when no matching residue template exists" do
      Chem::Topology::Templates["ASD"]?.should be_nil
    end
  end

  describe "#residue" do
    it "creates a residue template with multiple names" do
      Chem::Topology::Templates.residue do
        description "Anything"
        names "LXE", "EGR"
        stem "C1"
      end
      Chem::Topology::Templates["LXE"].should be Chem::Topology::Templates["EGR"]
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Topology::Templates::Error, "Duplicate residue template" do
        Chem::Topology::Templates.residue do
          description "Anything"
          name "LXE"
          stem "C1"
        end
      end
    end
  end
end
