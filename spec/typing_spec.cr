require "./spec_helper"

describe Chem::AtomType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::AtomType.new("CA").inspect.should eq "<AtomType CA>"
      Chem::AtomType.new("NZ", formal_charge: 1).inspect.should eq "<AtomType NZ+>"
      Chem::AtomType.new("SG", valency: 1).inspect.should eq "<AtomType SG(1)>"
    end
  end

  describe "#to_s" do
    it "returns atom name" do
      Chem::AtomType.new("CA").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::AtomType.new("NZ", formal_charge: 1).to_s.should eq "NZ+"
      Chem::AtomType.new("OE1", formal_charge: -1).to_s.should eq "OE1-"
      Chem::AtomType.new("NA", formal_charge: 2).to_s.should eq "NA+2"
      Chem::AtomType.new("UK", formal_charge: -5).to_s.should eq "UK-5"
    end

    it "returns atom name plus valency when its not nominal" do
      Chem::AtomType.new("SG", valency: 1).to_s.should eq "SG(1)"
    end
  end
end

describe Chem::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::BondType.new("CA", "CB").inspect.should eq "<BondType CA-CB>"
      Chem::BondType.new("C", "O", order: 2).inspect.should eq "<BondType C=O>"
      Chem::BondType.new("C", "N", order: 3).inspect.should eq "<BondType C#N>"
    end
  end
end

describe Chem::ResidueType do
  Chem::ResidueType.register do
    description "Anything"
    name "LFG"
    structure do
      stem "N1+-C2-C3-O4-C5-C6"
      branch "C5=O7"
    end
    root "C5"
  end

  describe ".fetch" do
    it "returns a residue type by name" do
      residue_t = Chem::ResidueType.fetch("LFG")
      residue_t.should be_a Chem::ResidueType
      residue_t.description.should eq "Anything"
      residue_t.name.should eq "LFG"
    end

    it "raises if residue type does not exist" do
      expect_raises Chem::Error, "Unknown residue type ASD" do
        Chem::ResidueType.fetch("ASD")
      end
    end

    it "returns block's return value if residue type does not exist" do
      Chem::ResidueType.fetch("ASD") { nil }.should be_nil
    end
  end

  describe ".register" do
    it "creates a residue template with multiple names" do
      Chem::ResidueType.register do
        description "Anything"
        name "LXE"
        aliases "EGR"
        structure "C1"
      end
      Chem::ResidueType.fetch("LXE").should be Chem::ResidueType.fetch("EGR")
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Error, "LXE residue type already exists" do
        Chem::ResidueType.register do
          description "Anything"
          name "LXE"
          structure do
            stem "C1"
          end
          root "C1"
        end
      end
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueType.build do
        name "O2"
        description "Molecular oxygen"
        structure "O1=O2"
        root "O1"
      end.inspect.should eq "<ResidueType O2>"

      Chem::ResidueType.build do
        name "HOH"
        kind :solvent
        description "Water"
        structure "O"
      end.inspect.should eq "<ResidueType HOH, solvent>"

      Chem::ResidueType.build do
        description "Glycine"
        name "GLY"
        code 'G'
        kind :protein
        structure do
          backbone
          remove_atom "HA"
        end
      end.inspect.should eq "<ResidueType GLY(G), protein>"
    end
  end
end

describe Chem::ResidueType::Builder do
  describe ".build" do
    bb_names = ["N", "H", "CA", "HA", "C", "O"]

    it "builds a residue without sidechain" do
      residue = Chem::ResidueType.build do
        description "Glycine"
        name "Gly"
        code 'G'
        kind :protein
        structure do
          backbone
          remove_atom "HA"
        end
      end

      residue.atom_names.should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
      residue.bonds.size.should eq 6
      residue.formal_charge.should eq 0
    end

    it "builds a residue with short sidechain" do
      residue = Chem::ResidueType.build do
        description "Alanine"
        name "ALA"
        code 'A'
        kind :protein
        structure do
          backbone
          sidechain "CB"
        end
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue with branched sidechain" do
      residue = Chem::ResidueType.build do
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

      names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                          "HD13", "CG2", "HG21", "HG22", "HG23"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 18
      residue.formal_charge.should eq 0
    end

    it "builds a positively charged residue" do
      residue = Chem::ResidueType.build do
        description "Lysine"
        name "LYS"
        code 'K'
        kind :protein
        structure do
          backbone
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
      residue = Chem::ResidueType.build do
        description "Aspartate"
        name "ASP"
        code 'D'
        kind :protein
        structure do
          backbone
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
      residue = Chem::ResidueType.build do
        description "Magnesium"
        name "MG"
        kind :ion
        structure do
          stem "MG+2"
        end
      end

      residue.formal_charge.should eq 2
    end

    it "builds a positively charged residue with one branch in the sidechain" do
      residue = Chem::ResidueType.build do
        description "Arginine"
        name "ARG"
        code 'R'
        kind :protein
        structure do
          backbone
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
      residue = Chem::ResidueType.build do
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

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                          "ND1", "HD1"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 17
      residue.formal_charge.should eq 0
    end

    it "builds a residue with a cyclic sidechain with terminal bond" do
      residue = Chem::ResidueType.build do
        description "Histidine"
        name "HIS"
        code 'H'
        kind :protein
        structure do
          backbone
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
      residue = Chem::ResidueType.build do
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

      names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                          "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 25
      residue.formal_charge.should eq 0
    end

    it "builds a cyclic residue" do
      residue = Chem::ResidueType.build do
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

      names = ["N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
               "HD1", "HD2"]
      residue.atom_names.should eq names
      residue.bonds.size.should eq 14
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency" do
      residue = Chem::ResidueType.build do
        description "Cysteine"
        name "CYX"
        code 'C'
        kind :protein
        structure do
          backbone
          sidechain "CB-SG(1)"
        end
      end

      residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "SG"]
      residue.bonds.size.should eq 9
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit valency followed by a bond" do
      residue = Chem::ResidueType.build do
        description "Sulfate"
        name "SO4"
        kind :ion
        structure "S(2)=O1"
        root "S"
      end

      residue.atom_names.should eq ["S", "O1"]
      residue.atom_types.map(&.valency).should eq [2, 2]
      residue.formal_charge.should eq 0
    end

    it "builds a residue having an atom with explicit element" do
      residue = Chem::ResidueType.build do
        description "Calcium"
        name "CA"
        kind :ion
        structure "CA[Ca]"
      end
      residue.atom_types[0].element.should eq Chem::PeriodicTable::Ca
    end

    it "builds a polymer residue" do
      residue_t = Chem::ResidueType.build do
        description "Fake"
        name "UNK"
        structure do
          stem "C1-C2-C3"
          link_adjacent_by "C3=C1"
        end
        root "C2"
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
      residue_t = Chem::ResidueType.build do
        description "Fake"
        name "UNK"
        structure "C1=C2"
        root "C2"
      end

      residue_t.atom_names.should eq ["C1", "H1", "H2", "C2", "H3", "H4"]
      residue_t.bonds.size.should eq 5
      residue_t.root_atom.should eq residue_t["C2"]
    end

    it "builds a residue with numbered atoms per element" do
      residue = Chem::ResidueType.build do
        description "Glycerol"
        name "GOL"
        kind :solvent
        structure do
          stem "O1-C1-C2-C3-O3"
          branch "C2-O2"
        end
        root "C2"
      end

      names = ["O1", "H1", "C1", "H4", "H5", "C2", "H6", "C3", "H7", "H8", "O3", "H3",
               "O2", "H2"]
      residue.atom_names.should eq names
    end

    it "builds a residue with four-letter atom names" do
      residue = Chem::ResidueType.build do
        description "C-ter"
        name "CTER"
        structure do
          stem "CA-C=O"
          branch "C-OXT"
        end
        root "C"
      end

      residue.atom_names.should eq ["CA", "HA1", "HA2", "HA3", "C", "O", "OXT", "HXT"]
    end

    it "fails when adding the same bond twice with different order" do
      # #cycle connects the first and last atoms with a single bond unless there is a
      # bond char (-, =, # or @) at the end. In this case, both CE2=CD2 and CD2-CE2 are
      # added
      expect_raises Chem::Error, "Bond CD2=CE2 already exists" do
        Chem::ResidueType.build do
          description "Tryptophan"
          name "TRP"
          code 'W'
          kind :protein

          structure do
            backbone
            stem "CB-CG"
            cycle "CG=CD1-NE1-CE2=CD2"
            cycle "CE2-CZ2=CH2-CZ3=CE3-CD2"
          end
        end
      end
    end

    it "fails on incorrect valency" do
      msg = "Atom type CG has incorrect valency (5), expected 4"
      expect_raises Chem::Error, msg do
        Chem::ResidueType.build do
          description "Tryptophan"
          name "TRP"
          code 'W'
          kind :protein

          structure do
            backbone
            sidechain do
              stem "CB-CG=CD"
              branch "CG-CZ"
              branch "CG-OTX-"
            end
          end
        end
      end
    end

    it "fails when adding a branch without existing root" do
      msg = "Branch must start with an existing atom type, got CB"
      expect_raises Chem::Error, msg do
        Chem::ResidueType.build do
          structure do
            branch "CB-CG2"
          end
        end
      end
    end

    it "builds a residue with symmetry" do
      residue = Chem::ResidueType.build do
        description "Donepezil"
        name "E20"
        structure do
          cycle "C1=C2-C3=C4-C5=C6"
          branch "C1-O25-C26"
          branch "C2-O27-C28"
          cycle "C4-C9-C8-C7-C5"
          branch "C8-C10-C11"
          cycle "C11-C12-C13-N14-C15-C16"
          branch "N14-C17-C18"
          cycle "C18=C19-C20=C21-C22=C23"
        end
        root "C1"
        symmetry({"C12", "C16"}, {"C13", "C15"})
        symmetry({"C19", "C23"}, {"C20", "C22"})
      end

      groups = residue.symmetric_atom_groups.should_not be_nil
      groups.size.should eq 2
      groups[0].should eq [{"C12", "C16"}, {"C13", "C15"}]
      groups[1].should eq [{"C19", "C23"}, {"C20", "C22"}]
    end

    it "raises if a symmetry atom is unknown" do
      expect_raises(Chem::Error, "Unknown atom type C13") do
        Chem::ResidueType.build do
          structure "C1=C2-C3=C4-C5=C6"
          symmetry({"C2", "C5"}, {"C13", "C15"})
        end
      end
    end

    it "raises if a symmetry atom is unknown" do
      expect_raises(Chem::Error, "C3 cannot be symmetric with itself") do
        Chem::ResidueType.build do
          structure "C1=C2-C3=C4-C5=C6"
          symmetry({"C2", "C4"}, {"C3", "C3"})
        end
      end
    end

    it "raises if a symmetry atom is repeated" do
      expect_raises(Chem::Error, "C2 cannot be reassigned for symmetry") do
        Chem::ResidueType.build do
          structure "C1=C2-C3=C4-C5=C6"
          symmetry({"C2", "C4"}, {"C5", "C2"})
        end
      end
    end

    it "raises if a bond specifies the same atom" do
      expect_raises Chem::Error, "Atom O cannot be bonded to itself" do
        Chem::ResidueType.build do
          name "O2"
          description "Molecular oxygen"
          structure "O=O"
          root "O"
        end
      end
    end

    it "raises if the link bond specifies the same atom" do
      expect_raises Chem::Error, "Atom O1 cannot be bonded to itself" do
        Chem::ResidueType.build do
          name "O2"
          description "Molecular oxygen"
          structure do
            stem "O1=O2"
            link_adjacent_by "O1=O1"
          end
          root "O"
        end
      end
    end

    it "raises if alias is called before name" do
      expect_raises(Chem::Error, "Aliases cannot be set for unnamed residue type") do
        Chem::ResidueType.register do
          aliases "WAT", "TIP3"
        end
      end
    end
  end
end
