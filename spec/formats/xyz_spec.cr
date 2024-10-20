require "../spec_helper"

describe Chem::XYZ::Reader do
  it "parses a XYZ file" do
    symbols = ["N", "C", "C", "O", "C", "H", "H", "H", "H", "H", "N", "C", "C", "O",
               "C", "S", "H", "H", "H", "H", "H", "N", "C", "C", "O", "C", "H", "H",
               "H", "H", "H", "N", "C", "C", "O", "C", "C", "S", "C", "H", "H", "H",
               "H", "H", "H", "H", "H", "H", "N", "C", "C", "O", "C", "H", "H", "H",
               "H", "H", "O", "H", "H"]

    structure = load_file "acama.xyz"
    structure.source_file.should eq Path[spec_file("acama.xyz")].expand
    structure.title.should eq "Ala-Cys-Ala-Met-Ala"
    structure.atoms.size.should eq 61
    structure.atoms.map(&.element.symbol).should eq symbols
    structure.atoms[11].pos.should eq [4.76610, 0.49650, 5.29840]
    structure.atoms[-1].pos.should eq [0.72200, 0.70700, 7.66970]
  end

  it "parses a XYZ file with multiple structures" do
    structures = Array(Chem::Structure).from_xyz spec_file("coo.trj.xyz")

    structures.size.should eq 4
    structures.map(&.title).should eq ["0", "1", "2", "3"]
    structures.map(&.atoms.size).should eq [3, 3, 3, 3]
    structures.map(&.atoms[1].z).should eq [1.159076, 1.2, 1.3, 1.4]
    structures.each do |structure|
      structure.source_file.should eq Path[spec_file("coo.trj.xyz")].expand
      structure.atoms.map(&.element.symbol).should eq ["C", "O", "O"]
    end
  end

  it "parses selected structures of a XYZ file with multiple structures" do
    path = spec_file("coo.trj.xyz")
    structures = Array(Chem::Structure).from_xyz path, indexes: [1, 3]

    structures.size.should eq 2
    structures.map(&.title).should eq ["1", "3"]
    structures.map(&.atoms.size).should eq [3, 3]
    structures.map(&.atoms[1].z).should eq [1.2, 1.4]
  end

  it "parses a XYZ file with atomic numbers" do
    io = IO::Memory.new <<-EOS
      9
      Three waters
      8   2.336   3.448   7.781
      1   1.446   3.485   7.315
      1   2.977   2.940   7.234
      8  11.776  11.590   8.510
      1  12.756  11.588   8.379
      1  11.395  11.031   7.787
      8   6.015  11.234   7.771
      1   6.440  12.040   7.394
      1   6.738  10.850   8.321
      EOS
    structure = Chem::Structure.from_xyz io
    structure.atoms.map(&.element.symbol).should eq %w(O H H O H H O H H)
  end

  it "fails when structure index is invalid" do
    expect_raises IndexError do
      Array(Chem::Structure).from_xyz spec_file("coo.trj.xyz"), indexes: [5]
    end
  end

  it "parses extended XYZ (#105)" do
    structure = Chem::Structure.from_xyz spec_file("extended.xyz")
    structure.title.should eq "Cubic Si"
    structure.cell.size.should eq Chem::Spatial::Size3[5.44, 5.44, 5.44]
    structure.cell.cubic?.should be_true
    structure.metadata.keys.sort!.should eq %w(
      converged dipole energy pressure step time wrap)
    structure.metadata["converged"].should be_true
    structure.metadata["dipole"].should eq [0.234, 1.234, 10.234]
    structure.metadata["energy"].should eq -123.5e-3
    structure.metadata["pressure"].should eq [1.23, 1.254, 0.923]
    structure.metadata["step"].should eq 515050
    structure.metadata["time"].should eq 1030.1
    structure.metadata["wrap"].should be_false
    structure.chains.map(&.id).should eq ['A', 'B', 'C']
    structure.chains.map(&.residues.size).should eq [4, 3, 1]
    structure.residues.map(&.name).should eq ["SIL"] * 8
    structure.residues.map(&.number).should eq [1, 2, 3, 4, 1, 2, 3, 1]
    structure.atoms.size.should eq 8
    structure.atoms.map(&.element).uniq!.should eq [Chem::PeriodicTable::Si]
    structure.atoms[-2].pos.should eq vec3(0, 2.72, 2.72)
    structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 2, 0, 0, 1, 0]
    structure.atoms.count(&.partial_charge.zero?).should eq 8
    structure.atoms.each_with_index do |atom, i|
      atom.metadata.keys.sort!.should eq %w(dd label)
      atom.metadata["dd"].should eq [0.1, 0.2, 0.3]
      atom.metadata["label"].should eq "si#{i + 1}"
    end
  end
end

describe Chem::XYZ::Writer do
  it "writes a structure" do
    structure = Chem::Structure.build do
      title "COO-"
      atom :c, vec3(0, 0, 0)
      atom :o, vec3(0, 0, 1.159076)
      atom :o, vec3(0, 0, -1.159076)
    end

    structure.chains[0].atoms.to_xyz.should eq <<-EOS
      3

      C     0.000    0.000    0.000
      O     0.000    0.000    1.159
      O     0.000    0.000   -1.159

      EOS
  end

  it "writes multiple structures" do
    structure = Chem::Structure.build do
      title "COO-"
      atom :c, vec3(1, 0, 0)
      atom :o, vec3(2, 0, 0)
      atom :o, vec3(3, 0, 0)
    end

    io = IO::Memory.new
    Chem::XYZ::Writer.open(io) do |xyz|
      (1..3).each do |i|
        structure.title = "COO- Step #{i}"
        structure.pos.map! &.*(i)
        xyz << structure
      end
    end

    io.to_s.should eq <<-EOS
      3
      COO- Step 1
      C     1.000    0.000    0.000
      O     2.000    0.000    0.000
      O     3.000    0.000    0.000
      3
      COO- Step 2
      C     2.000    0.000    0.000
      O     4.000    0.000    0.000
      O     6.000    0.000    0.000
      3
      COO- Step 3
      C     6.000    0.000    0.000
      O    12.000    0.000    0.000
      O    18.000    0.000    0.000

      EOS
  end

  it "writes extended" do
    structure = Chem::Structure.from_xyz spec_file("extended.xyz")
    structure.to_xyz(
      extended: true,
      fields: %w(constraint chain resid resname charge dd label)
    ).should eq <<-EOS
      8
      Title="Cubic Si" Properties=species:S:1:pos:R:3:constraint:L:3:chain:S:1:resid:I:1:resname:S:1:charge:I:1:dd:R:3:label:S:1 Lattice=[[5.44, 0.0, 0.0], [0.0, 5.44, 0.0], [0.0, 0.0, 5.44]] Energy=-0.1235 Dipole=[0.234, 1.234, 10.234] Pressure=[1.23, 1.254, 0.923] Time=1030.1 Step=515050 Converged=true Wrap=false
      Si    0.000    0.000    0.000 T F F A    1 SIL   0      0.1     0.2     0.3 si1
      Si    1.360    1.360    1.360 T F F A    2 SIL   0      0.1     0.2     0.3 si2
      Si    2.720    2.720    0.000 T F F A    3 SIL   0      0.1     0.2     0.3 si3
      Si    4.080    4.080    1.360 T F F A    4 SIL   2      0.1     0.2     0.3 si4
      Si    2.720    0.000    2.720 T F F B    1 SIL   0      0.1     0.2     0.3 si5
      Si    4.080    1.360    4.080 T F F B    2 SIL   0      0.1     0.2     0.3 si6
      Si    0.000    2.720    2.720 T T T B    3 SIL   1      0.1     0.2     0.3 si7
      Si    1.360    4.080    4.080 T T T C    1 SIL   0      0.1     0.2     0.3 si8

      EOS
  end
end
