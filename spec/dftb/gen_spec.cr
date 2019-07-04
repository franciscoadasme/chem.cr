require "../spec_helper"

describe Chem::DFTB::Gen::PullParser do
  it "parses a non-periodic Gen file" do
    content = <<-EOS
      5  C
      Cl Na  O
        1 1    3.0000000000E+01    1.5000000000E+01    1.0000000000E+01
        2 2    1.0000000000E+01    5.0000000000E+00    5.0000000000E+00
        3 3    3.0000000000E+01    1.5000000000E+01    9.0000000000E+00
        4 2    1.0000000000E+01    1.0000000000E+01    1.2500000000E+01
        5 1    2.0000000000E+01    1.0000000000E+01    1.0000000000E+01
      EOS

    structure = Chem::DFTB::Gen::PullParser.new(content).parse
    structure.lattice.should be_nil

    structure.n_atoms.should eq 5
    structure.atoms.map(&.element.symbol).should eq ["Cl", "Na", "O", "Na", "Cl"]
    structure.atoms[0].coords.should eq V[30, 15, 10]
    structure.atoms[1].coords.should eq V[10, 5, 5]
    structure.atoms[2].coords.should eq V[30, 15, 9]
    structure.atoms[3].coords.should eq V[10, 10, 12.5]
    structure.atoms[4].coords.should eq V[20, 10, 10]
  end

  it "parses a periodic Gen file" do
    content = <<-EOS
      4  S
      Cl O  Na
        1 1    3.0000000000E+01    1.5000000000E+01    1.0000000000E+01
        2 2    1.0000000000E+01    5.0000000000E+00    5.0000000000E+00
        3 2    3.0000000000    1.5000000000    9.0000000000
        4 3    1.0000000000    1.0000000000    1.2500000000
        0.0000000000E+00    0.0000000000E+00    0.0000000000E+00
        4.0000000000E+01    0.0000000000E+00    0.0000000000E+00
        0.0000000000E+00    2.0000000000E+01    0.0000000000E+00
        0.0000000000E+00    0.0000000000E+00    1.0000000000E+01
      EOS

    structure = Chem::DFTB::Gen::PullParser.new(content).parse
    structure.lattice.should_not be_nil
    structure.lattice.not_nil!.a.should eq V[40, 0, 0]
    structure.lattice.not_nil!.b.should eq V[0, 20, 0]
    structure.lattice.not_nil!.c.should eq V[0, 0, 10]

    structure.n_atoms.should eq 4
    structure.atoms.map(&.element.symbol).should eq ["Cl", "O", "O", "Na"]
    structure.atoms[0].coords.should eq V[30, 15, 10]
    structure.atoms[1].coords.should eq V[10, 5, 5]
    structure.atoms[2].coords.should eq V[3, 1.5, 9]
    structure.atoms[3].coords.should eq V[1, 1, 1.25]
  end

  it "parses a Gen file having fractional coordinates" do
    content = <<-EOS
      2 F
      Ga As
      1 1 0.0 0.0 0.0
      2 2 0.25 0.25 0.25
      0.000000 0.000000 0.000000
      2.713546 2.713546 0.0
      0.0 2.713546 2.713546
      2.713546 0.0 2.713546
      EOS

    structure = Chem::DFTB::Gen::PullParser.new(content).parse
    structure.lattice.should_not be_nil
    structure.lattice.not_nil!.a.should eq V[2.713546, 2.713546, 0]
    structure.lattice.not_nil!.b.should eq V[0, 2.713546, 2.713546]
    structure.lattice.not_nil!.c.should eq V[2.713546, 0, 2.713546]

    structure.n_atoms.should eq 2
    structure.atoms.map(&.element.symbol).should eq ["Ga", "As"]
    structure.atoms[0].coords.should eq V[0, 0, 0]
    structure.atoms[1].coords.should eq V[1.356773, 1.356773, 1.356773]
  end
end

describe Chem::DFTB::Gen::Builder do
  structure = Chem::Structure.build do
    title "NaCl-O-NaCl"
    atom PeriodicTable::Cl, at: V[30, 15, 10]
    atom PeriodicTable::Na, at: V[10, 5, 5]
    atom PeriodicTable::O, at: V[30, 15, 9]
    atom PeriodicTable::Na, at: V[10, 10, 12.5]
    atom PeriodicTable::Cl, at: V[20, 10, 10]
  end

  it "writes a structure in cartersian coordinats without unit cell" do
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

  it "writes a structure in cartersian coordinats with unit cell" do
    structure.lattice = Chem::Lattice.orthorombic 40, 20, 10
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

  it "writes a structure in fractional coordinats with unit cell" do
    structure.lattice = Chem::Lattice.orthorombic 40, 20, 10
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

  it "fails when writing a non-periodic structure in fractional coordinates" do
    expect_raises IO::Error, "Cannot write a non-periodic structure" do
      Chem::Structure.new.to_gen fractional: true
    end
  end
end
