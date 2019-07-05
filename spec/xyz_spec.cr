require "./spec_helper"

describe Chem::XYZ::PullParser do
  it "parses a XYZ file" do
    symbols = ["N", "C", "C", "O", "C", "H", "H", "H", "H", "H", "N", "C", "C", "O",
               "C", "S", "H", "H", "H", "H", "H", "N", "C", "C", "O", "C", "H", "H",
               "H", "H", "H", "N", "C", "C", "O", "C", "C", "S", "C", "H", "H", "H",
               "H", "H", "H", "H", "H", "H", "N", "C", "C", "O", "C", "H", "H", "H",
               "H", "H", "O", "H", "H"]

    content = File.read "spec/data/xyz/acama.xyz"
    structure = Chem::XYZ::PullParser.new(content).parse

    structure.title.should eq "Ala-Cys-Ala-Met-Ala"
    structure.n_atoms.should eq 61
    structure.atoms.map(&.element.symbol).should eq symbols
    structure.atoms[11].coords.should eq V[4.76610, 0.49650, 5.29840]
    structure.atoms[-1].coords.should eq V[0.72200, 0.70700, 7.66970]
  end

  it "parses a XYZ file with multiple structures" do
    content = File.read "spec/data/xyz/coo.trj.xyz"
    structures = Chem::XYZ::PullParser.new(content).parse_all

    structures.size.should eq 4
    structures.map(&.title).should eq ["0", "1", "2", "3"]
    structures.map(&.n_atoms).should eq [3, 3, 3, 3]
    structures.map(&.atoms[1].z).should eq [1.159076, 1.2, 1.3, 1.4]
    structures.each do |structure|
      structure.atoms.map(&.element.symbol).should eq ["C", "O", "O"]
    end
  end

  it "parses selected structures of a XYZ file with multiple structures" do
    content = File.read "spec/data/xyz/coo.trj.xyz"
    structures = Chem::XYZ::PullParser.new(content).parse indexes: [1, 3]

    structures.size.should eq 2
    structures.map(&.title).should eq ["1", "3"]
    structures.map(&.n_atoms).should eq [3, 3]
    structures.map(&.atoms[1].z).should eq [1.2, 1.4]
  end

  it "fails when structure index is invalid" do
    expect_raises IndexError do
      content = File.read "spec/data/xyz/coo.trj.xyz"
      Chem::XYZ::PullParser.new(content).parse indexes: [5]
    end
  end
end

describe Chem::XYZ::Builder do
  it "writes a structure" do
    structure = Chem::Structure.build do
      title "COO-"
      atom :c, V[0, 0, 0]
      atom :o, V[0, 0, 1.159076]
      atom :o, V[0, 0, -1.159076]
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
      atom :c, V[1, 0, 0]
      atom :o, V[2, 0, 0]
      atom :o, V[3, 0, 0]
    end

    xyz = Chem::XYZ.build do |xyz|
      (1..3).each do |i|
        structure.title = "COO- Step #{i}"
        structure.coords.map! &.*(i)
        structure.to_xyz xyz
      end
    end

    xyz.should eq <<-EOS
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
