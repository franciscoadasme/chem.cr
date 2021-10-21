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
    structure.n_atoms.should eq 61
    structure.atoms.map(&.element.symbol).should eq symbols
    structure.atoms[11].coords.should eq Vec3[4.76610, 0.49650, 5.29840]
    structure.atoms[-1].coords.should eq Vec3[0.72200, 0.70700, 7.66970]
  end

  it "parses a XYZ file with multiple structures" do
    structures = Array(Chem::Structure).from_xyz spec_file("coo.trj.xyz")

    structures.size.should eq 4
    structures.map(&.title).should eq ["0", "1", "2", "3"]
    structures.map(&.n_atoms).should eq [3, 3, 3, 3]
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
    structures.map(&.n_atoms).should eq [3, 3]
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
    structure = Structure.from_xyz io
    structure.atoms.map(&.element.symbol).should eq %w(O H H O H H O H H)
  end

  it "fails when structure index is invalid" do
    expect_raises IndexError do
      Array(Chem::Structure).from_xyz spec_file("coo.trj.xyz"), indexes: [5]
    end
  end
end

describe Chem::XYZ::Writer do
  it "writes a structure" do
    structure = Chem::Structure.build do
      title "COO-"
      atom :c, Vec3[0, 0, 0]
      atom :o, Vec3[0, 0, 1.159076]
      atom :o, Vec3[0, 0, -1.159076]
    end

    structure.chains[0].to_xyz.should eq <<-EOS
      3

      C          0.00000        0.00000        0.00000
      O          0.00000        0.00000        1.15908
      O          0.00000        0.00000       -1.15908\n
      EOS
  end

  it "writes multiple structures" do
    structure = Chem::Structure.build do
      title "COO-"
      atom :c, Vec3[1, 0, 0]
      atom :o, Vec3[2, 0, 0]
      atom :o, Vec3[3, 0, 0]
    end

    io = IO::Memory.new
    Chem::XYZ::Writer.open(io) do |xyz|
      (1..3).each do |i|
        structure.title = "COO- Step #{i}"
        structure.coords.map! &.*(i)
        xyz << structure
      end
    end

    io.to_s.should eq <<-EOS
      3
      COO- Step 1
      C          1.00000        0.00000        0.00000
      O          2.00000        0.00000        0.00000
      O          3.00000        0.00000        0.00000
      3
      COO- Step 2
      C          2.00000        0.00000        0.00000
      O          4.00000        0.00000        0.00000
      O          6.00000        0.00000        0.00000
      3
      COO- Step 3
      C          6.00000        0.00000        0.00000
      O         12.00000        0.00000        0.00000
      O         18.00000        0.00000        0.00000

      EOS
  end
end
