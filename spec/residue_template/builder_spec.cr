require "../spec_helper"

describe Chem::ResidueTemplate::Builder do
  bb_names = ["N", "H", "CA", "HA", "C", "O"]

  it "builds a residue without sidechain" do
    res_t = build_template do
      description "Glycine"
      name "Gly"
      code 'G'
      type :protein
      spec "N(-H)-CA(-C=O)"
    end
    res_t.atoms.map(&.name).should eq ["N", "H", "CA", "HA1", "HA2", "C", "O"]
    res_t.bonds.size.should eq 6
    res_t.formal_charge.should eq 0
  end

  it "builds a residue with short sidechain" do
    res_t = build_template do
      description "Alanine"
      name "ALA"
      code 'A'
      type :protein
      spec "{backbone}-CB"
    end
    res_t.atoms.map(&.name).should eq bb_names + ["CB", "HB1", "HB2", "HB3"]
    res_t.bonds.size.should eq 9
    res_t.formal_charge.should eq 0
  end

  it "builds a residue with branched sidechain" do
    res_t = build_template do
      description "Isoleucine"
      name "ILE"
      code 'I'
      type :protein
      spec "{backbone}-CB(-CG1-CD1)-CG2"
    end
    names = bb_names + ["CB", "HB", "CG1", "HG11", "HG12", "CD1", "HD11", "HD12",
                        "HD13", "CG2", "HG21", "HG22", "HG23"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 18
    res_t.formal_charge.should eq 0
  end

  it "builds a positively charged residue" do
    res_t = build_template do
      description "Lysine"
      name "LYS"
      code 'K'
      type :protein
      spec "{backbone}-CB-CG-CD-CE-[NZH3+]"
    end
    names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                        "CE", "HE1", "HE2", "NZ", "HZ1", "HZ2", "HZ3"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 21
    res_t.formal_charge.should eq 1
  end

  it "builds a negatively charged residue" do
    res_t = build_template do
      description "Aspartate"
      name "ASP"
      code 'D'
      type :protein
      spec "{backbone}-CB-CG(=OE1)-[OE2-]"
    end
    res_t.atoms.map(&.name).should eq(bb_names + ["CB", "HB1", "HB2", "CG", "OE1", "OE2"])
    res_t.bonds.size.should eq 11
    res_t.formal_charge.should eq -1
  end

  it "builds a residue with charge +2" do
    res_t = build_template do
      name "MG"
      spec "[MG+2]"
    end
    res_t.atoms.size.should eq 1
    res_t.bonds.size.should eq 0
    res_t.formal_charge.should eq 2
  end

  it "builds a positively charged residue with one branch in the sidechain" do
    res_t = build_template do
      description "Arginine"
      name "ARG"
      code 'R'
      type :protein
      spec "{backbone}-CB-CG-CD-NE-CZ(-NH1)=[NH2H2+]"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD", "HD1", "HD2",
                        "NE", "HE", "CZ", "NH1", "HH11", "HH12", "NH2", "HH21",
                        "HH22"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 23
    res_t.formal_charge.should eq 1
  end

  it "builds a residue with a cyclic sidechain" do
    res_t = build_template do
      description "Histidine"
      name "HIS"
      code 'H'
      type :protein
      spec "{backbone}-CB-CG%1=CD2-NE2=CE1-ND1-%1"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "CD2", "HD2", "NE2", "CE1", "HE1",
                        "ND1", "HD1"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 17
    res_t.formal_charge.should eq 0
  end

  it "builds a residue with a cyclic sidechain with terminal bond" do
    res_t = build_template do
      description "Histidine"
      name "HIS"
      code 'H'
      type :protein
      spec "{backbone}-CB-CG%1-ND1-CE1=NE2-CD2=%1"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "ND1", "HD1", "CE1", "HE1", "NE2",
                        "CD2", "HD2"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 17
    res_t.formal_charge.should eq 0
  end

  it "builds a residue with a bicyclic sidechain" do
    res_t = build_template do
      description "Tryptophan"
      name "TRP"
      code 'W'
      type :protein
      spec "{backbone}-CB-CG%1=CD1-NE1-CE2(=CD2%2-%1)-CZ2=CH2-CZ3=CE3-%2"
    end

    names = bb_names + ["CB", "HB1", "HB2", "CG", "CD1", "HD1", "NE1", "HE1", "CE2",
                        "CD2", "CZ2", "HZ2", "CH2", "HH2", "CZ3", "HZ3", "CE3", "HE3"]
    res_t.atoms.map(&.name).should eq names
    res_t.bonds.size.should eq 25
    res_t.formal_charge.should eq 0
  end

  it "builds a cyclic residue" do
    res_t = build_template do
      description "Proline"
      name "PRO"
      code 'P'
      type :protein
      spec "N%1-CA(-C=O)-CB-CG-CD-%1"
    end
    res_t.atoms.map(&.name).should eq [
      "N", "CA", "HA", "C", "O", "CB", "HB1", "HB2", "CG", "HG1", "HG2", "CD",
      "HD1", "HD2",
    ]
    res_t.bonds.size.should eq 14
    res_t.formal_charge.should eq 0
  end

  it "builds a polymer residue" do
    res_t = build_template do
      name "UNK"
      spec "C1-C2-C3"
      link_adjacent_by "C3=C1"
    end
    res_t.atoms.map(&.name).should eq ["C1", "H1", "C2", "H2", "H3", "C3", "H4"]
    res_t.bonds.size.should eq 6
    res_t.polymer?.should be_true
    bond_t = res_t.link_bond.should_not be_nil
    bond_t.atoms.map(&.name).to_a.should eq %w(C3 C1)
    bond_t.order.should eq 2
  end

  it "builds a rooted residue" do
    res_t = build_template do
      name "UNK"
      spec "C1=C2"
      root "C2"
    end

    res_t.atoms.map(&.name).should eq ["C1", "H1", "H2", "C2", "H3", "H4"]
    res_t.bonds.size.should eq 5
    res_t.root_atom.should eq res_t["C2"]
  end

  it "builds a residue with numbered atoms per element" do
    res_t = build_template do
      description "Glycerol"
      name "GOL"
      type :solvent
      spec "O1-C1-C2(-C3-O3)-O2"
    end
    res_t.atoms.map(&.name).should eq [
      "O1", "H1", "C1", "H2", "H3", "C2", "H4", "C3", "H5", "H6", "O3", "H7",
      "O2", "H8",
    ]
  end

  it "builds a residue with four-letter atom names" do
    res_t = build_template do
      name "CTER"
      spec "CA-C(=O)-OXT"
    end
    res_t.atoms.map(&.name).should eq ["CA", "HA1", "HA2", "HA3", "C", "O", "OXT", "HXT"]
  end

  it "fails on incorrect valence" do
    expect_raises(Chem::Error, "Expected valence of CG is 4, got 5") do
      build_template do
        description "Tryptophan"
        name "TRP"
        code 'W'
        type :protein
        spec "{backbone}-CB-CG(=CD)(-CZ)-[OTX-]"
      end
    end
  end

  it "builds a residue with symmetry" do
    res_t = build_template do
      description "Donepezil"
      name "E20"
      spec <<-SPEC.gsub(/\s+/, "")
          C1%1(-O25-C26)=C2(-O27-C28)-C3=C4(-C5%2=C6-%1)-C9-C8
          (-C7(=O24)-%2)-C10-C11%3-C12-C13-N14(-C15-C16-%3)
          -C17-C18%4=C19-C20=C21-C22=C23-%4
          SPEC
      symmetry({"C12", "C16"}, {"C13", "C15"})
      symmetry({"C19", "C23"}, {"C20", "C22"})
    end

    groups = res_t.symmetric_atom_groups.should_not be_nil
    groups.size.should eq 2
    groups[0].should eq [{"C12", "C16"}, {"C13", "C15"}]
    groups[1].should eq [{"C19", "C23"}, {"C20", "C22"}]
  end

  it "raises if a symmetry atom is unknown" do
    expect_raises(Chem::Error, "Unknown atom C13") do
      build_template do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C5"}, {"C13", "C15"})
      end
    end
  end

  it "raises if a symmetry pair includes the same atom" do
    expect_raises(Chem::Error, "C3 cannot be symmetric with itself") do
      build_template do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C4"}, {"C3", "C3"})
      end
    end
  end

  it "raises if a symmetry atom is repeated" do
    expect_raises(Chem::Error, "C2 cannot be reassigned for symmetry") do
      build_template do
        spec "C1%1=C2-C3=C4-C5=C6-%1"
        symmetry({"C2", "C4"}, {"C5", "C2"})
      end
    end
  end

  it "raises if the link bond specifies the same atom" do
    expect_raises Chem::Error, "Atom O1 cannot be bonded to itself" do
      build_template do
        name "O2"
        spec "O1=O2"
        link_adjacent_by "O1=O1"
      end
    end
  end

  it "handles multiple valencies" do
    res_t = build_template do
      name "UNK"
      spec "CB-SG"
    end
    res_t.atoms.size.should eq 6
    res_t.atoms.count(&.element.hydrogen?).should eq 4
    res_t.atoms.map(&.valence).should eq [4, 1, 1, 1, 2, 1]
    res_t.bonds.size.should eq 5
    res_t.bonds.count(&.includes?("SG")).should eq 2

    res_t = build_template do
      name "UNK"
      spec "CB-[SG-]"
    end
    res_t.atoms.size.should eq 5
    res_t.atoms.count(&.element.hydrogen?).should eq 3
    res_t.atoms.map(&.valence).should eq [4, 1, 1, 1, 2]
    res_t.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, -1]
    res_t.bonds.size.should eq 4
    res_t.bonds.count(&.includes?("SG")).should eq 1

    res_t = build_template do
      name "UNK"
      spec "S(=O1)(=O2)(-[O3-])(-[O4-])"
    end
    res_t.atoms.size.should eq 5
    res_t.atoms.count(&.element.hydrogen?).should eq 0
    res_t.atoms.map(&.valence).should eq [6, 2, 2, 2, 2]
    res_t.atoms.map(&.formal_charge).should eq [0, 0, 0, -1, -1]
    res_t.bonds.size.should eq 4
    res_t.bonds.count(&.includes?("S")).should eq 4
  end

  it "handles implicit bonds" do
    res_t = build_template do
      description "Cysteine"
      name "CYX"
      spec "CB-SG-*"
    end
    res_t.atoms.size.should eq 5
    res_t.atoms.count(&.element.hydrogen?).should eq 3
    res_t.bonds.size.should eq 4
    res_t.bonds.count(&.includes?("SG")).should eq 1
  end

  it "guesses root to be the most complex atom" do
    res_t = build_template do
      name "TRP"
      spec "{backbone}-CB-CG%1=CD1-NE1-CE2(-CZ2=CH2-CZ3=CE3-CD2%2)=%2-%1"
    end
    res_t.root_atom.should eq res_t["CE2"]

    res_t = build_template do
      name "DMPE"
      spec "C1-C2-C3-C4-C5-C6-C7-C8-C9-C10-C11-C12-C13-C14(-O1)-O2-C15\
            (-C16-O3-C17(-O4)-C18-C19-C20-C21-C22-C23-C24-C25-C26-C27\
            -C28-C29-C30)-C31-O5-P1(=O6)(=O7)-O8-C32-C33-N1"
    end
    res_t.root_atom.should eq res_t["P1"]
  end
end

private def build_template(&) : Chem::ResidueTemplate
  spec_aliases = {"backbone" => "N(-H)-CA(-HA)(-C=O)"}
  builder = Chem::ResidueTemplate::Builder.new spec_aliases
  with builder yield builder
  builder.build
end
