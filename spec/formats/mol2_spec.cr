require "../spec_helper"

describe Chem::Mol2::Reader do
  it "parses a Mol2 file" do
    structure = load_file "benzene.mol2"
    structure.source_file.should eq Path[spec_file("benzene.mol2")].expand
    structure.title.should eq "benzene"
    structure.residues[0].name.should eq "BEN"

    atoms = structure.atoms
    atoms.size.should eq 12
    atoms.map(&.name).should eq ["C1", "C2", "C3", "C4", "C5", "C6", "H1", "H2", "H3",
                                 "H4", "H5", "H6"]
    atoms[0].element.should eq Chem::PeriodicTable::C
    atoms[4].partial_charge.should eq -0.062
    atoms[5].coords.should eq [0, 1.394, 0]
    atoms[6].element.should eq Chem::PeriodicTable::H
    atoms[8].coords.should eq [3.353, -0.542, 0]
    atoms[9].partial_charge.should eq 0.062
    atoms[11].element.should eq Chem::PeriodicTable::H
    atoms[11].coords.should eq [-0.939, 1.936, 0]

    atoms[0].bonds[atoms[1]].order.should eq 2
    atoms[1].bonds[atoms[2]].order.should eq 1
    atoms[2].bonds[atoms[3]].order.should eq 2
    atoms[3].bonds[atoms[4]].order.should eq 1
    atoms[4].bonds[atoms[5]].order.should eq 2
    atoms[5].bonds[atoms[0]].order.should eq 1
    6.times { |i| atoms[i].bonds[atoms[i + 6]].order.should eq 1 }
  end

  it "parses an unformatted Mol2 file with minimal information" do
    atom_names = ["N1", "C2", "C3", "C4", "O5", "C6", "N7", "C8", "C9", "N10", "H11",
                  "O12", "H13", "H14", "H15", "H16", "H17", "H18", "H19", "H20"]
    symbols = atom_names.map { |name| Chem::PeriodicTable[name[0]].symbol }

    structure = load_file "minimal.mol2"
    structure.source_file.should eq Path[spec_file("minimal.mol2")].expand
    structure.title.should eq "Histidine"

    atoms = structure.atoms
    atoms.size.should eq 20
    atoms.map(&.name).should eq atom_names
    atoms.map(&.element.symbol).should eq symbols
    atoms[2].coords.should eq [-0.2043, -0.1565, -0.4766]
    atoms[14].coords.should eq [-0.7202, -1.1105, -0.3899]

    atoms[3].bonded_atoms.map(&.serial).should eq [2, 5, 12]
    atoms[3].bonds[atoms[4]].order.should eq 2
    atoms[3].bonds[atoms[11]].order.should eq 1
    atoms[8].bonds[atoms[9]].order.should eq 2
  end

  it "parses multiple structures" do
    ary = Array(Chem::Structure).from_mol2 spec_file("molecules.mol2")
    ary.size.should eq 12

    structure = ary.first
    structure.source_file.should eq Path[spec_file("molecules.mol2")].expand
    atoms = structure.atoms
    atoms[0].name.should eq "N1"
    atoms[0].element.nitrogen?.should be_true
    atoms[0].partial_charge.should eq -0.896
    atoms[0].coords.should be_close [6.8420, 9.9900, 22.7430], 1e-4
    atoms[33].name.should eq "H131"
    atoms[33].element.hydrogen?.should be_true
    atoms[33].partial_charge.should eq 0.072
    atoms[33].coords.should be_close [4.5540, 11.1000, 22.5880], 1e-4

    structure.bonds.size.should eq 51
    atoms[7].bonded?(atoms[34]).should be_true
    atoms[13].bonded?(atoms[19]).should be_true
  end

  it "reads weird atom names" do
    structure = load_file "weird_names.mol2"
    structure.atoms[12].name.should eq "C1'"
  end

  it "reads unit cell" do
    structure = load_file("water_in_box.mol2")
    cell = structure.cell.should_not be_nil
    cell.size.should be_close [40.961, 18.65, 22.52], 1e-3
    cell.alpha.should be_close 90, 1e-2
    cell.beta.should be_close 90.77, 1e-2
    cell.gamma.should be_close 120, 1e-2
  end

  it "sets formal charges" do
    structure = load_file "charged.mol2"
    structure.formal_charge.should eq 0
    structure.dig('A', 1, "N5").formal_charge.should eq 1
    structure.dig('A', 1, "O23").formal_charge.should eq -1
  end
end

describe Chem::Mol2::Writer do
  it "writes a structure" do
    structure = Chem::Structure.build do
      title "Sulfur"

      chain 'C' do
        residue "SO4", 45 do
          atom "S1", vec3(-0.0002, 0.0003, 0.0001), partial_charge: 1.2618
          atom "O2", vec3(-1.3618, -0.5756, -0.1010), partial_charge: -0.7248
          atom "H3", vec3(0.7821, -0.8842, 0.6252), partial_charge: -0.5475
          atom "H4", vec3(0.4755, 0.1646, -1.2374), partial_charge: -0.5482
          atom "O5", vec3(0.1044, 1.2949, 0.7131), partial_charge: -0.7244

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
         1 SO445        1 RESIDUE  * C SO4\n

      EOS
  end

  it "writes cell" do
    structure = load_file("waters.xyz", guess_topology: true)
    structure.cell = Chem::Spatial::Parallelepiped.new({40.961, 18.65, 22.52}, {90, 90.77, 120})
    structure.to_mol2.should eq File.read(spec_file("water_in_box.mol2"))
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
