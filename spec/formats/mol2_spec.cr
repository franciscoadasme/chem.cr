require "../spec_helper"

describe Chem::Mol2 do
  describe ".each" do
    it "yields each structure" do
      collected = [] of Chem::Structure
      Chem::Mol2.each spec_file("molecules.mol2") do |s|
        collected << s
      end
      collected.size.should eq 12
      collected.first.atoms[0].name.should eq "N1"
    end
  end

  describe ".read" do
    it "parses a Mol2 file" do
      path = Path[spec_file("benzene.mol2")]
      struc = Chem::Mol2.read path
      struc.source_file.should eq path.expand
      struc.title.should eq "benzene"
      struc.residues[0].name.should eq "BEN"

      atoms = struc.atoms
      atoms.size.should eq 12
      atoms.map(&.name).should eq ["C1", "C2", "C3", "C4", "C5", "C6", "H1", "H2", "H3",
                                   "H4", "H5", "H6"]
      atoms[0].element.should eq Chem::PeriodicTable::C
      atoms[4].partial_charge.should eq -0.062
      atoms[5].pos.should eq [0, 1.394, 0]
      atoms[6].element.should eq Chem::PeriodicTable::H
      atoms[8].pos.should eq [3.353, -0.542, 0]
      atoms[9].partial_charge.should eq 0.062
      atoms[11].element.should eq Chem::PeriodicTable::H
      atoms[11].pos.should eq [-0.939, 1.936, 0]

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

      path = Path[spec_file("minimal.mol2")]
      struc = Chem::Mol2.read path
      struc.source_file.should eq path.expand
      struc.title.should eq "Histidine"

      atoms = struc.atoms
      atoms.size.should eq 20
      atoms.map(&.name).should eq atom_names
      atoms.map(&.element.symbol).should eq symbols
      atoms[2].pos.should eq [-0.2043, -0.1565, -0.4766]
      atoms[14].pos.should eq [-0.7202, -1.1105, -0.3899]

      atoms[3].bonded_atoms.map(&.number).should eq [2, 5, 12]
      atoms[3].bonds[atoms[4]].order.should eq 2
      atoms[3].bonds[atoms[11]].order.should eq 1
      atoms[8].bonds[atoms[9]].order.should eq 2
    end

    it "reads weird atom names" do
      struc = Chem::Mol2.read spec_file("weird_names.mol2")
      struc.atoms[12].name.should eq "C1'"
    end

    it "reads unit cell" do
      struc = Chem::Mol2.read spec_file("water_in_box.mol2")
      cell = struc.cell?.should_not be_nil
      cell.size.should be_close [40.961, 18.65, 22.52], 1e-3
      cell.angles.should be_close({90, 90.77, 120}, 1e-2)
    end

    it "sets formal charges" do
      struc = Chem::Mol2.read spec_file("charged.mol2")
      struc.formal_charge.should eq 0
      struc.dig('A', 1, "N5").formal_charge.should eq 1
      struc.dig('A', 1, "O23").formal_charge.should eq -1
    end
  end

  describe ".read_all" do
    it "returns all structures" do
      ary = Chem::Mol2.read_all spec_file("molecules.mol2")
      ary.size.should eq 12

      struc = ary.first
      struc.source_file.should eq Path[spec_file("molecules.mol2")].expand
      atoms = struc.atoms
      atoms[0].name.should eq "N1"
      atoms[0].element.nitrogen?.should be_true
      atoms[0].partial_charge.should eq -0.896
      atoms[0].pos.should be_close [6.8420, 9.9900, 22.7430], 1e-4
      atoms[33].name.should eq "H131"
      atoms[33].element.hydrogen?.should be_true
      atoms[33].partial_charge.should eq 0.072
      atoms[33].pos.should be_close [4.5540, 11.1000, 22.5880], 1e-4

      struc.bonds.size.should eq 51
      atoms[7].bonded?(atoms[34]).should be_true
      atoms[13].bonded?(atoms[19]).should be_true
    end
  end

  describe ".write" do
    it "writes a structure" do
      struc = Chem::Structure.build do
        title "Sulfur"

        chain 'C' do
          residue "SO4", 45 do
            atom "S1", vec3(-0.0002, 0.0003, 0.0001), partial_charge: 1.2618
            atom "O2", vec3(-1.3618, -0.5756, -0.1010), partial_charge: -0.7248
            atom "H3", vec3(0.7821, -0.8842, 0.6252), partial_charge: -0.5475
            atom "H4", vec3(0.4755, 0.1646, -1.2374), partial_charge: -0.5482
            atom "O5", vec3(0.1044, 1.2949, 0.7131), partial_charge: -0.7244

            bond "S1", "O2", :double
            bond "S1", "H3"
            bond "S1", "H4"
            bond "S1", "O5", :double
          end
        end
      end

      io = IO::Memory.new
      Chem::Mol2.write io, struc
      io.to_s.should eq <<-EOS
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
      struc = Chem::XYZ.read spec_file("waters.xyz"), guess_bonds: true, guess_names: true
      struc.cell = Chem::Spatial::Parallelepiped.new({40.961, 18.65, 22.52}, {90, 90.77, 120})
      io = IO::Memory.new
      Chem::Mol2.write io, struc
      io.to_s.should eq File.read(spec_file("water_in_box.mol2"))
    end

    it "raises if structure has no bonds" do
      struc = Chem::Mol2.read spec_file("tac.mol2")
      struc.atoms.each do |atom|
        atom.bonded_atoms.each do |other|
          atom.bonds.delete other
        end
      end
      expect_raises(Chem::Error, "Structure has no bonds") do
        Chem::Mol2.write IO::Memory.new, struc
      end
    end
  end
end
