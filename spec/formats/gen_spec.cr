require "../spec_helper"

describe Chem::Gen::Reader do
  it "parses a non-periodic Gen file" do
    structure = load_file "non_periodic.gen", topology: :none
    structure.lattice.should be_nil

    structure.n_atoms.should eq 5
    structure.atoms.map(&.element.symbol).should eq ["Cl", "Na", "O", "Na", "Cl"]
    structure.coords.should eq [
      V[30, 15, 10],
      V[10, 5, 5],
      V[30, 15, 9],
      V[10, 10, 12.5],
      V[20, 10, 10],
    ]
  end

  it "parses a periodic Gen file" do
    structure = load_file "periodic.gen", topology: :none
    structure.lattice.should_not be_nil
    structure.lattice.not_nil!.i.should eq V[40, 0, 0]
    structure.lattice.not_nil!.j.should eq V[0, 20, 0]
    structure.lattice.not_nil!.k.should eq V[0, 0, 10]

    structure.n_atoms.should eq 4
    structure.atoms.map(&.element.symbol).should eq ["Cl", "O", "O", "Na"]
    structure.coords.should eq [
      V[30, 15, 10],
      V[10, 5, 5],
      V[3, 1.5, 9],
      V[1, 1, 1.25],
    ]
  end

  it "parses a Gen file having fractional coordinates" do
    structure = load_file "fractional.gen", topology: :none
    structure.lattice.should_not be_nil
    structure.lattice.not_nil!.i.should eq V[2.713546, 2.713546, 0]
    structure.lattice.not_nil!.j.should eq V[0, 2.713546, 2.713546]
    structure.lattice.not_nil!.k.should eq V[2.713546, 0, 2.713546]

    structure.n_atoms.should eq 2
    structure.atoms.map(&.element.symbol).should eq ["Ga", "As"]
    structure.coords.should eq [V[0, 0, 0], V[1.356773, 1.356773, 1.356773]]
  end
end

describe Chem::Gen::Writer do
  structure = Chem::Structure.build(guess_topology: false) do
    title "NaCl-O-NaCl"
    atom PeriodicTable::Cl, V[30, 15, 10]
    atom PeriodicTable::Na, V[10, 5, 5]
    atom PeriodicTable::O, V[30, 15, 9]
    atom PeriodicTable::Na, V[10, 10, 12.5]
    atom PeriodicTable::Cl, V[20, 10, 10]
  end

  it "writes a structure in Cartesian coordinats without unit cell" do
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
    structure.lattice = Lattice.new S[40, 20, 10]
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
    structure.lattice = Lattice.new S[40, 20, 10]
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

  it "writes an atom collection" do
    structure.chains[0].to_gen.should eq <<-EOS
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
