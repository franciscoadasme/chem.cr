require "../../spec_helper"

describe Chem::VASP::Chgcar do
  it "parses a CHGCAR" do
    grid = Grid.from_chgcar "spec/data/vasp/CHGCAR"
    grid.dim.should eq({2, 2, 2})
    grid.bounds.should eq Bounds[10, 10, 10]
    grid.volume.should eq 1_000
    grid[0, 0, 0].should be_close 7.8406017013, 1e-10
    grid[-1, -1, -1].should be_close 1.0024522914, 1e-10
    grid[1, 0, 0].should be_close 7.6183317989, 1e-10
  end

  it "writes a CHGCAR" do
    st = Chem::Structure.build do
      title "NaCl-O-NaCl"
      lattice 5, 10, 20
      atom :Cl, V[30, 15, 10]
      atom :Na, V[10, 5, 5]
      atom :O, V[30, 15, 9]
      atom :Na, V[10, 10, 12.5]
      atom :Cl, V[20, 10, 10]
    end

    grid = make_grid(3, 3, 3, Bounds[5, 10, 20]) { |i, j, k| i * 100 + j * 10 + k }
    grid.to_chgcar(structure: st).should eq <<-EOF
      NaCl-O-NaCl
         1.00000000000000
           5.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   10.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   20.0000000000000000
         Cl   Na   O 
           2     2     1
      Cartesian
         30.0000000000000000   15.0000000000000000   10.0000000000000000
         20.0000000000000000   10.0000000000000000   10.0000000000000000
         10.0000000000000000    5.0000000000000000    5.0000000000000000
         10.0000000000000000   10.0000000000000000   12.5000000000000000
         30.0000000000000000   15.0000000000000000    9.0000000000000000

          3    3    3
       0.00000000000E+00 1.00000000000E+05 2.00000000000E+05 1.00000000000E+04 1.10000000000E+05
       2.10000000000E+05 2.00000000000E+04 1.20000000000E+05 2.20000000000E+05 1.00000000000E+03
       1.01000000000E+05 2.01000000000E+05 1.10000000000E+04 1.11000000000E+05 2.11000000000E+05
       2.10000000000E+04 1.21000000000E+05 2.21000000000E+05 2.00000000000E+03 1.02000000000E+05
       2.02000000000E+05 1.20000000000E+04 1.12000000000E+05 2.12000000000E+05 2.20000000000E+04
       1.22000000000E+05 2.22000000000E+05

      EOF
  end

  it "fails when writing a CHGCAR with a non-periodic structure" do
    grid = make_grid 3, 3, 3, Bounds.zero
    expect_raises Chem::Spatial::NotPeriodicError do
      grid.to_chgcar structure: Chem::Structure.new
    end
  end
end
