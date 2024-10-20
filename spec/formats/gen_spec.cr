require "../spec_helper"

describe Chem::Gen::Reader do
  it "parses a non-periodic Gen file" do
    structure = load_file "non_periodic.gen"
    structure.source_file.should eq Path[spec_file("non_periodic.gen")].expand
    structure.cell?.should be_nil

    structure.atoms.size.should eq 5
    structure.atoms.map(&.element.symbol).should eq ["Cl", "Na", "O", "Na", "Cl"]
    structure.pos.should eq [
      [30, 15, 10],
      [10, 5, 5],
      [30, 15, 9],
      [10, 10, 12.5],
      [20, 10, 10],
    ]
  end

  it "parses a periodic Gen file" do
    structure = load_file "periodic.gen"
    structure.source_file.should eq Path[spec_file("periodic.gen")].expand
    cell = structure.cell?.should_not be_nil
    cell.basis.should eq Chem::Spatial::Mat3.basis(
      vec3(40, 0, 0),
      vec3(0, 20, 0),
      vec3(0, 0, 10))

    structure.atoms.size.should eq 4
    structure.atoms.map(&.element.symbol).should eq ["Cl", "O", "O", "Na"]
    structure.pos.should eq [
      [30, 15, 10],
      [10, 5, 5],
      [3, 1.5, 9],
      [1, 1, 1.25],
    ]
  end

  it "parses a Gen file having fractional coordinates" do
    structure = load_file "fractional.gen"
    structure.source_file.should eq Path[spec_file("fractional.gen")].expand
    cell = structure.cell?.should_not be_nil
    cell.not_nil!.basis.should eq Chem::Spatial::Mat3.basis(
      vec3(2.713546, 2.713546, 0),
      vec3(0, 2.713546, 2.713546),
      vec3(2.713546, 0, 2.713546)
    )

    structure.atoms.size.should eq 2
    structure.atoms.map(&.element.symbol).should eq ["Ga", "As"]
    structure.pos.should eq [[0, 0, 0], [1.356773, 1.356773, 1.356773]]
  end
end

describe Chem::Gen::Writer do
  structure = Chem::Structure.build do
    title "NaCl-O-NaCl"
    atom Chem::PeriodicTable::Cl, vec3(30, 15, 10)
    atom Chem::PeriodicTable::Na, vec3(10, 5, 5)
    atom Chem::PeriodicTable::O, vec3(30, 15, 9)
    atom Chem::PeriodicTable::Na, vec3(10, 10, 12.5)
    atom Chem::PeriodicTable::Cl, vec3(20, 10, 10)
  end

  it "writes a structure in Cartesian coordinates without unit cell" do
    structure.to_gen.should eq <<-EOS
          5  C
       Cl Na  O
          1 1    3.0000000000E+01    1.5000000000E+01    1.0000000000E+01
          2 2    1.0000000000E+01    5.0000000000E+00    5.0000000000E+00
          3 3    3.0000000000E+01    1.5000000000E+01    9.0000000000E+00
          4 2    1.0000000000E+01    1.0000000000E+01    1.2500000000E+01
          5 1    2.0000000000E+01    1.0000000000E+01    1.0000000000E+01\n
      EOS
  end

  it "writes a structure in Cartesian coordinates with unit cell" do
    structure.cell = Chem::Spatial::Parallelepiped.new({40, 20, 10})
    structure.to_gen.should eq <<-EOS
          5  S
       Cl Na  O
          1 1    3.0000000000E+01    1.5000000000E+01    1.0000000000E+01
          2 2    1.0000000000E+01    5.0000000000E+00    5.0000000000E+00
          3 3    3.0000000000E+01    1.5000000000E+01    9.0000000000E+00
          4 2    1.0000000000E+01    1.0000000000E+01    1.2500000000E+01
          5 1    2.0000000000E+01    1.0000000000E+01    1.0000000000E+01
          0.0000000000E+00    0.0000000000E+00    0.0000000000E+00
          4.0000000000E+01    0.0000000000E+00    0.0000000000E+00
          0.0000000000E+00    2.0000000000E+01    0.0000000000E+00
          0.0000000000E+00    0.0000000000E+00    1.0000000000E+01\n
      EOS
  end

  it "writes a structure in fractional coordinates with unit cell" do
    structure.cell = Chem::Spatial::Parallelepiped.new({40, 20, 10})
    structure.to_gen(fractional: true).should eq <<-EOS
          5  F
       Cl Na  O
          1 1    7.5000000000E-01    7.5000000000E-01    1.0000000000E+00
          2 2    2.5000000000E-01    2.5000000000E-01    5.0000000000E-01
          3 3    7.5000000000E-01    7.5000000000E-01    9.0000000000E-01
          4 2    2.5000000000E-01    5.0000000000E-01    1.2500000000E+00
          5 1    5.0000000000E-01    5.0000000000E-01    1.0000000000E+00
          0.0000000000E+00    0.0000000000E+00    0.0000000000E+00
          4.0000000000E+01    0.0000000000E+00    0.0000000000E+00
          0.0000000000E+00    2.0000000000E+01    0.0000000000E+00
          0.0000000000E+00    0.0000000000E+00    1.0000000000E+01\n
      EOS
  end

  it "writes atoms" do
    structure.chains[0].atoms.to_gen.should eq <<-EOS
          5  C
       Cl Na  O
          1 1    3.0000000000E+01    1.5000000000E+01    1.0000000000E+01
          2 2    1.0000000000E+01    5.0000000000E+00    5.0000000000E+00
          3 3    3.0000000000E+01    1.5000000000E+01    9.0000000000E+00
          4 2    1.0000000000E+01    1.0000000000E+01    1.2500000000E+01
          5 1    2.0000000000E+01    1.0000000000E+01    1.0000000000E+01\n
      EOS
  end

  it "fails when writing a non-periodic structure in fractional coordinates" do
    expect_raises Chem::Spatial::NotPeriodicError do
      Chem::Structure.new.to_gen fractional: true
    end
  end
end
