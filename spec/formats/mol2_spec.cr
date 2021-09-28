require "../spec_helper"

describe Chem::Mol2::Reader do
  it "parses a Mol2 file" do
    content = <<-EOS
      # Name: benzene
      # Creating user name: tom
      # Creation time: Wed Dec 28 00:18:30 1988

      # Modifying user name: tom
      # Modification time: Wed Dec 28 00:18:30 1988

      @<TRIPOS>MOLECULE
      benzene
      12 12 1 0 0
      SMALL
      MULLIKEN_CHARGES
      ****
      Charges were calculated with b3lyp/6-31g*

      @<TRIPOS>ATOM
      1     C1    1.207    2.091    0.000    C.ar    1    BENZENE   -0.062
      2     C2    2.414    1.394    0.000    C.ar    1    BENZENE   -0.062
      3     C3    2.414    0.000    0.000    C.ar    1    BENZENE   -0.062
      4     C4    1.207   -0.697    0.000    C.ar    1    BENZENE   -0.062
      5     C5    0.000    0.000    0.000    C.ar    1    BENZENE   -0.062
      6     C6    0.000    1.394    0.000    C.ar    1    BENZENE   -0.062
      7     H1    1.207    3.175    0.000    H       1    BENZENE    0.062
      8     H2    3.353    1.936    0.000    H       1    BENZENE    0.062
      9     H3    3.353   -0.542    0.000    H       1    BENZENE    0.062
      10    H4    1.207   -1.781    0.000    H       1    BENZENE    0.062
      11    H5   -0.939   -0.542    0.000    H       1    BENZENE    0.062
      12    H6   -0.939    1.936    0.000    H       1    BENZENE    0.062

      @<TRIPOS>BOND
      1     1     2    ar
      2     1     6    ar
      3     2     3    ar
      4     3     4    ar
      5     4     5    ar
      6     5     6    ar
      7     1     7    1
      8     2     8    1
      9     3     9    1
      10    4    10    1
      11    5    11    1
      12    6    12    1

      @<TRIPOS>SUBSTRUCTURE
      1    BENZENE1    PERM    0    ****    ****    0    ROOT
      EOS

    structure = Chem::Structure.from_mol2 IO::Memory.new(content)
    structure.title.should eq "benzene"
    structure.residues[0].name.should eq "BEN"

    atoms = structure.atoms
    atoms.size.should eq 12
    atoms.map(&.name).should eq ["C1", "C2", "C3", "C4", "C5", "C6", "H1", "H2", "H3",
                                 "H4", "H5", "H6"]
    atoms[0].element.should eq Chem::PeriodicTable::C
    atoms[4].partial_charge.should eq -0.062
    atoms[5].coords.should eq V[0, 1.394, 0]
    atoms[6].element.should eq Chem::PeriodicTable::H
    atoms[8].coords.should eq V[3.353, -0.542, 0]
    atoms[9].partial_charge.should eq 0.062
    atoms[11].element.should eq Chem::PeriodicTable::H
    atoms[11].coords.should eq V[-0.939, 1.936, 0]

    atoms[0].bonds[atoms[1]].order.should eq 2
    atoms[1].bonds[atoms[2]].order.should eq 1
    atoms[2].bonds[atoms[3]].order.should eq 2
    atoms[3].bonds[atoms[4]].order.should eq 1
    atoms[4].bonds[atoms[5]].order.should eq 2
    atoms[5].bonds[atoms[0]].order.should eq 1
    6.times { |i| atoms[i].bonds[atoms[i + 6]].order.should eq 1 }
  end

  it "parses an unformatted Mol2 file with minimal information" do
    content = <<-EOS
      @<TRIPOS>MOLECULE
      Histidine
      20 20 1 0 2
      SMALL
      NO_CHARGES

      @<TRIPOS>ATOM
      1 N1 -1.0947 0.5371 1.7186 N.4
      2 C2 -0.9885 0.9170 0.2765 C.3
      3 C3 -0.2043 -0.1565 -0.4766 C.3
      4 C4 -2.3725 1.0376 -0.3154 C.2
      5 O5 -2.7546 2.1336 -0.8057 O.co2
      6 C6 1.1797 -0.2771 0.1153 C.2
      7 N7 2.2791 0.4215 -0.2757 N.pl3
      8 C8 1.5387 -1.0911 1.1173 C.2
      9 C9 3.3256 0.0285 0.4990 C.2
      10 N10 2.9039 -0.8872 1.3511 N.2
      11 H11 -1.6259 1.2643 2.2287 H
      12 O12 -3.1452 0.0423 -0.3188 O.co2
      13 H13 -0.1461 0.4545 2.1242 H
      14 H14 -0.4726 1.8710 0.1898 H
      15 H15 -0.7202 -1.1105 -0.3899 H
      16 H16 -0.1270 0.1200 -1.5261 H
      17 H17 2.3126 1.1114 -1.0125 H
      18 H18 0.8943 -1.7774 1.6466 H
      19 H19 4.3357 0.4040 0.4286 H
      20 H20 -1.5855 -0.3703 1.8010 H

      @<TRIPOS>BOND
      1 1 2 1
      2 2 3 1
      3 2 4 1
      4 3 6 1
      5 4 5 2
      6 6 7 1
      7 6 8 2
      8 7 9 1
      9 8 10 1
      10 9 10 2
      11 1 11 1
      12 4 12 1
      13 1 13 1
      14 2 14 1
      15 3 15 1
      16 3 16 1
      17 7 17 1
      18 8 18 1
      19 9 19 1
      20 1 20 1
      EOS
    atom_names = ["N1", "C2", "C3", "C4", "O5", "C6", "N7", "C8", "C9", "N10", "H11",
                  "O12", "H13", "H14", "H15", "H16", "H17", "H18", "H19", "H20"]
    symbols = atom_names.map { |name| PeriodicTable[name[0]].symbol }

    structure = Chem::Structure.from_mol2 IO::Memory.new(content)
    structure.title.should eq "Histidine"

    atoms = structure.atoms
    atoms.size.should eq 20
    atoms.map(&.name).should eq atom_names
    atoms.map(&.element.symbol).should eq symbols
    atoms[2].coords.should eq V[-0.2043, -0.1565, -0.4766]
    atoms[14].coords.should eq V[-0.7202, -1.1105, -0.3899]

    atoms[3].bonded_atoms.map(&.serial).should eq [2, 5, 12]
    atoms[3].bonds[atoms[4]].order.should eq 2
    atoms[3].bonds[atoms[11]].order.should eq 1
    atoms[8].bonds[atoms[9]].order.should eq 2
  end

  it "parses multiple structures" do
    ary = Array(Chem::Structure).from_mol2 "spec/data/mol2/molecules.mol2"
    ary.size.should eq 12

    structure = ary.first
    atoms = structure.atoms
    atoms[0].name.should eq "N1"
    atoms[0].element.nitrogen?.should be_true
    atoms[0].partial_charge.should eq -0.896
    atoms[0].coords.should be_close V[6.8420, 9.9900, 22.7430], 1e-4
    atoms[33].name.should eq "H131"
    atoms[33].element.hydrogen?.should be_true
    atoms[33].partial_charge.should eq 0.072
    atoms[33].coords.should be_close V[4.5540, 11.1000, 22.5880], 1e-4

    structure.bonds.size.should eq 51
    atoms[7].bonded?(atoms[34]).should be_true
    atoms[13].bonded?(atoms[19]).should be_true
  end

  it "reads weird atom names" do
    structure = load_file "weird_names.mol2"
    structure.atoms[12].name.should eq "C1'"
  end
end

describe Chem::Mol2::Writer do
  it "writes a structure" do
    structure = Chem::Structure.build do
      title "Sulfur"

      chain 'C' do
        residue "SO4", 45 do
          atom "S1", V[-0.0002, 0.0003, 0.0001], partial_charge: 1.2618
          atom "O2", V[-1.3618, -0.5756, -0.1010], partial_charge: -0.7248
          atom "H3", V[0.7821, -0.8842, 0.6252], partial_charge: -0.5475
          atom "H4", V[0.4755, 0.1646, -1.2374], partial_charge: -0.5482
          atom "O5", V[0.1044, 1.2949, 0.7131], partial_charge: -0.7244

          bond "S1", "O2", order: 2
          bond "S1", "H3"
          bond "S1", "H4"
          bond "S1", "O5", order: 2
        end
      end
    end

    structure.to_mol2.should eq <<-EOS
      @<TRIPOS>MOLECULE
      Sulfur
          5    4   1
      UNKNOWN
      USER_CHARGES

      @<TRIPOS>ATOM
          1 S1     -0.0002    0.0003    0.0001 S      1 SO445    1.2618
          2 O2     -1.3618   -0.5756   -0.1010 O      1 SO445   -0.7248
          3 H3      0.7821   -0.8842    0.6252 H      1 SO445   -0.5475
          4 H4      0.4755    0.1646   -1.2374 H      1 SO445   -0.5482
          5 O5      0.1044    1.2949    0.7131 O      1 SO445   -0.7244

      @<TRIPOS>BOND
          1    1    2 2
          2    1    3 1
          3    1    4 1
          4    1    5 2

      @<TRIPOS>SUBSTRUCTURE
         1 SO445       1 RESIDUE  1 C SO4  4\n

      EOS
  end

  it "raises if structure has no bonds" do
    structure = load_file "tac.mol2"
    structure.atoms.each do |atom|
      atom.bonded_atoms.each do |other|
        atom.bonds.delete other
      end
    end
    expect_raises(Chem::Error, "Structure has no bonds") do
      structure.to_mol2
    end
  end
end
