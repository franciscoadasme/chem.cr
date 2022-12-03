require "../spec_helper"

describe Chem::ResidueTemplate::Builder do
  bb_names = ["N", "H", "CA", "HA", "C", "O"]

  it "builds a residue without sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Glycine"
      name "Gly"
      code 'G'
      type :protein
      spec "N(-H)-CA(-C=O)"
    end
    residue.atom_names.should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
    residue.bonds.size.should eq 6
    residue.formal_charge.should eq 0
  end

  it "builds a residue with short sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Alanine"
      name "ALA"
      code 'A'
      type :protein
      spec "{backbone}-CB"
    end
    residue.atom_names.should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
    residue.bonds.size.should eq 9
    residue.formal_charge.should eq 0
  end

  it "builds a residue with branched sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Isoleucine"
      name "ILE"
      code 'I'
      type :protein
      spec "{backbone}-CB(-CG1-CD1)-CG2"
    end
    names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                        "HD13", "CG2", "HG21", "HG22", "HG23"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 18
    residue.formal_charge.should eq 0
  end

  it "builds a positively charged residue" do
    residue = Chem::ResidueTemplate.build do
      description "Lysine"
      name "LYS"
      code 'K'
      type :protein
      spec "{backbone}-CB-CG-CD-CE-[NZH3+]"
    end
    names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                        "CE", "HE1", "HE2", "NZ", "HZ1", "HZ2", "HZ3"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 21
    residue.formal_charge.should eq 1
  end

  it "builds a negatively charged residue" do
    residue = Chem::ResidueTemplate.build do
      description "Aspartate"
      name "ASP"
      code 'D'
      type :protein
      spec "{backbone}-CB-CG(=OE1)-[OE2-]"
    end
    residue.atom_names.should eq(bb_names + ["CB", "HB1", "HB2", "CG", "OE1", "OE2"])
    residue.bonds.size.should eq 11
    residue.formal_charge.should eq -1
  end

  it "builds a residue with charge +2" do
    residue = Chem::ResidueTemplate.build do
      name "MG"
      spec "[MG+2]"
    end
    residue.atoms.size.should eq 1
    residue.bonds.size.should eq 0
    residue.formal_charge.should eq 2
  end

  it "builds a positively charged residue with one branch in the sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Arginine"
      name "ARG"
      code 'R'
      type :protein
      spec "{backbone}-CB-CG-CD-NE-CZ(-NH1)=[NH2H2+]"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                        "NE", "HE", "CZ", "NH1", "HH11", "HH12", "NH2", "HH21",
                        "HH22"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 23
    residue.formal_charge.should eq 1
  end

  it "builds a residue with a cyclic sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Histidine"
      name "HIS"
      code 'H'
      type :protein
      spec "{backbone}-CB-CG%1=CD2-NE2=CE1-ND1-%1"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                        "ND1", "HD1"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 17
    residue.formal_charge.should eq 0
  end

  it "builds a residue with a cyclic sidechain with terminal bond" do
    residue = Chem::ResidueTemplate.build do
      description "Histidine"
      name "HIS"
      code 'H'
      type :protein
      spec "{backbone}-CB-CG%1-ND1-CE1=NE2-CD2=%1"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "ND1", "HD1", "CE1", "HE1", "NE2",
                        "CD2", "HD2"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 17
    residue.formal_charge.should eq 0
  end

  it "builds a residue with a bicyclic sidechain" do
    residue = Chem::ResidueTemplate.build do
      description "Tryptophan"
      name "TRP"
      code 'W'
      type :protein
      spec "{backbone}-CB-CG%1=CD1-NE1-CE2(=CD2%2-%1)-CZ2=CH2-CZ3=CE3-%2"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                        "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
    residue.atom_names.should eq names
    residue.bonds.size.should eq 25
    residue.formal_charge.should eq 0
  end

  it "builds a cyclic residue" do
    residue = Chem::ResidueTemplate.build do
      description "Proline"
      name "PRO"
      code 'P'
      type :protein
      spec "N%1-CA(-C=O)-CB-CG-CD-%1"
    end
    residue.atom_names.should eq [
      "N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
      "HD1", "HD2",
    ]
    residue.bonds.size.should eq 14
    residue.formal_charge.should eq 0
  end

  it "builds a polymer residue" do
    residue_t = Chem::ResidueTemplate.build do
      name "UNK"
      spec "C1-C2-C3"
      link_adjacent_by "C3=C1"
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
    residue_t = Chem::ResidueTemplate.build do
      name "UNK"
      spec "C1=C2"
      root "C2"
    end

    residue_t.atom_names.should eq ["C1", "H1", "H2", "C2", "H3", "H4"]
    residue_t.bonds.size.should eq 5
    residue_t.root_atom.should eq residue_t["C2"]
  end

  it "builds a residue with numbered atoms per element" do
    residue = Chem::ResidueTemplate.build do
      description "Glycerol"
      name "GOL"
      type :solvent
      spec "O1-C1-C2(-C3-O3)-O2"
      root "C2"
    end
    residue.atom_names.should eq [
      "O1", "H1", "C1", "H2", "H3", "C2", "H4", "C3", "H5", "H6", "O3", "H7",
      "O2", "H8",
    ]
  end

  it "builds a residue with four-letter atom names" do
    residue = Chem::ResidueTemplate.build do
      name "CTER"
      spec "CA-C(=O)-OXT"
      root "C"
    end
    residue.atom_names.should eq ["CA", "HA1", "HA2", "HA3", "C", "O", "OXT", "HXT"]
  end

  it "fails on incorrect valence" do
    expect_raises(Chem::Error, "Expected valence of CG is 4, got 5") do
      Chem::ResidueTemplate.build do
        description "Tryptophan"
        name "TRP"
        code 'W'
        type :protein
        spec "{backbone}-CB-CG(=CD)(-CZ)-[OTX-]"
      end
    end
  end

  it "builds a residue with symmetry" do
    residue = Chem::ResidueTemplate.build do
      description "Donepezil"
      name "E20"
      spec <<-SPEC.gsub(/\s+/, "")
          C1%1(-O25-C26)=C2(-O27-C28)-C3=C4(-C5%2=C6-%1)-C9-C8
          (-C7(=O24)-%2)-C10-C11%3-C12-C13-N14(-C15-C16-%3)
          -C17-C18%4=C19-C20=C21-C22=C23-%4
          SPEC
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
    expect_raises(Chem::Error, "Unknown atom C13") do
      Chem::ResidueTemplate.build do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C5"}, {"C13", "C15"})
      end
    end
  end

  it "raises if a symmetry pair includes the same atom" do
    expect_raises(Chem::Error, "C3 cannot be symmetric with itself") do
      Chem::ResidueTemplate.build do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C4"}, {"C3", "C3"})
      end
    end
  end

  it "raises if a symmetry atom is repeated" do
    expect_raises(Chem::Error, "C2 cannot be reassigned for symmetry") do
      Chem::ResidueTemplate.build do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C4"}, {"C5", "C2"})
      end
    end
  end

  it "raises if the link bond specifies the same atom" do
    expect_raises Chem::Error, "Atom O1 cannot be bonded to itself" do
      Chem::ResidueTemplate.build do
        name "O2"
        spec "O1=O2"
        link_adjacent_by "O1=O1"
        root "O"
      end
    end
  end

  it "handles multiple valencies" do
    rtype = Chem::ResidueTemplate.build do
      name "UNK"
      spec "CB-SG"
      root "CB"
    end
    rtype.atoms.size.should eq 6
    rtype.atoms.count(&.element.hydrogen?).should eq 4
    rtype.atoms.map(&.valence).should eq [4, 1, 1, 1, 2, 1]
    rtype.bonds.size.should eq 5
    rtype.bonds.count(&.includes?("SG")).should eq 2

    rtype = Chem::ResidueTemplate.build do
      name "UNK"
      spec "CB-[SG-]"
      root "CB"
    end
    rtype.atoms.size.should eq 5
    rtype.atoms.count(&.element.hydrogen?).should eq 3
    rtype.atoms.map(&.valence).should eq [4, 1, 1, 1, 2]
    rtype.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, -1]
    rtype.bonds.size.should eq 4
    rtype.bonds.count(&.includes?("SG")).should eq 1

    rtype = Chem::ResidueTemplate.build do
      name "UNK"
      spec "S(=O1)(=O2)(-[O3-])(-[O4-])"
      root "S"
    end
    rtype.atoms.size.should eq 5
    rtype.atoms.count(&.element.hydrogen?).should eq 0
    rtype.atoms.map(&.valence).should eq [6, 2, 2, 2, 2]
    rtype.atoms.map(&.formal_charge).should eq [0, 0, 0, -1, -1]
    rtype.bonds.size.should eq 4
    rtype.bonds.count(&.includes?("S")).should eq 4
  end

  it "handles implicit bonds" do
    rtype = Chem::ResidueTemplate.build do
      description "Cysteine"
      name "CYX"
      spec "CB-SG-*"
      root "CB"
    end
    rtype.atoms.size.should eq 5
    rtype.atoms.count(&.element.hydrogen?).should eq 3
    rtype.bonds.size.should eq 4
    rtype.bonds.count(&.includes?("SG")).should eq 1
  end
end
