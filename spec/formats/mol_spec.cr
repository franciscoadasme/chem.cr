require "../spec_helper"

describe Chem::Mol::Reader do
  it "parses a Mol V2000 file" do
    path = Path[spec_file("702_v2000.mol")]
    structure = Chem::Structure.read path
    structure.source_file.should eq path.expand
    structure.title.should eq ""
    structure.atoms.size.should eq 9
    structure.bonds.size.should eq 8
    structure.atoms.reject(&.formal_charge.zero?)
      .to_h { |atom| {atom.number, atom.formal_charge} }
      .should eq({1 => -2, 4 => 1, 6 => -1})
    structure.bonds.reject(&.single?)
      .to_h { |bond| {bond.atoms.map(&.number), bond.order.to_i} }
      .should eq({ {1, 2} => 2 })
    structure.atoms[2].mass.should eq 14
    structure.residues.map(&.name).should eq ["702"]
  end

  it "parses a Mol V3000 file" do
    path = Path[spec_file("702_v3000.mol")]
    structure = Chem::Structure.read path
    structure.source_file.should eq path.expand
    structure.title.should eq "Schrodinger Suite 2021-4."
    structure.atoms.size.should eq 9
    structure.bonds.size.should eq 8
    structure.atoms.reject(&.formal_charge.zero?)
      .to_h { |atom| {atom.number, atom.formal_charge} }
      .should eq({1 => -2, 4 => 1, 6 => -1})
    structure.bonds.reject(&.single?)
      .to_h { |bond| {bond.atoms.map(&.number), bond.order.to_i} }
      .should eq({ {1, 2} => 2 })
    structure.atoms[2].mass.should eq 14
    structure.residues.map(&.name).should eq ["702"]
  end
end

describe Chem::Mol::Writer do
  it "writes a Mol V2000 file" do
    structure = Chem::Structure.read(spec_file("702_v2000.mol"))
    structure.to_mol.strip.should eq <<-MOL
      702
        chem.cr #{Time.local.to_s("%m%d%y%H%M")}2D

        9  8  0  0  0  0  0  0  0  0999 V2000
          0.5369    0.9749    0.0000 O   0  6  0  0  0  0  0  0  0  0  0  0
          1.4030    0.4749    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
          2.2690    0.9749    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
          1.8015    0.0000    0.0000 H   0  3  0  0  0  0  0  0  0  0  0  0
          1.0044    0.0000    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
          1.9590    1.5118    0.0000 H   0  5  0  0  0  0  0  0  0  0  0  0
          2.8059    1.2849    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
          2.5790    0.4380    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
          0.0000    0.6649    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
        1  2  2  0  0  0  0
        1  9  1  0  0  0  0
        2  3  1  0  0  0  0
        2  4  1  0  0  0  0
        2  5  1  0  0  0  0
        3  6  1  0  0  0  0
        3  7  1  0  0  0  0
        3  8  1  0  0  0  0
      M  CHG  3   1  -2   4   1   6  -1
      M  END
      MOL
  end

  it "writes a Mol V3000 file" do
    structure = Chem::Structure.read(spec_file("702_v2000.mol"))
    structure.to_mol(:v3000).strip.should eq <<-MOL
      702
        chem.cr #{Time.local.to_s("%m%d%y%H%M")}2D

        0  0  0  0  0  0  0  0  0  0999 V3000
      M  V30 BEGIN CTAB
      M  V30 COUNTS 9 8 0 0 0
      M  V30 BEGIN ATOM
      M  V30 1    O      0.5369    0.9749    0.0000 0 CHG=-2
      M  V30 2    C      1.4030    0.4749    0.0000 0
      M  V30 3    C      2.2690    0.9749    0.0000 0
      M  V30 4    H      1.8015    0.0000    0.0000 0 CHG=1
      M  V30 5    H      1.0044    0.0000    0.0000 0
      M  V30 6    H      1.9590    1.5118    0.0000 0 CHG=-1
      M  V30 7    H      2.8059    1.2849    0.0000 0
      M  V30 8    H      2.5790    0.4380    0.0000 0
      M  V30 9    H      0.0000    0.6649    0.0000 0
      M  V30 END ATOM
      M  V30 BEGIN BOND
      M  V30 1     2  1  2
      M  V30 2     1  1  9
      M  V30 3     1  2  3
      M  V30 4     1  2  4
      M  V30 5     1  2  5
      M  V30 6     1  3  6
      M  V30 7     1  3  7
      M  V30 8     1  3  8
      M  V30 END BOND
      M  V30 END CTAB
      M END
      MOL
  end
end
