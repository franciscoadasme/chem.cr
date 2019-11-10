require "./spec_helper"

alias Lattice = Chem::Lattice

describe Chem::Lattice do
  describe ".new" do
    it "succeeds with vectors" do
      lattice = Lattice.new Vector[8.77, 0, 0],
        Vector[3.19616011, 8.94620370, 0],
        Vector[4.29605592, -0.71878676, 24.35353874]
      lattice.size.to_a.should be_close [8.77, 9.5, 24.740], 1e-8
      lattice.alpha.should be_close 88.22, 1e-8
      lattice.beta.should be_close 80.00, 1e-7
      lattice.gamma.should be_close 70.34, 1e-7
    end

    it "succeeds with size and angles" do
      lattice = Lattice.new({74.23, 135.35, 148.46}, {90.0, 90.0, 90.0})
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
    end

    it "succeeds with sizes (orthorombic box)" do
      lattice = Lattice.orthorombic 74.23, 135.35, 148.46
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
    end
  end

  describe ".[]" do
    it "works" do
      expected = Lattice.new Vector[74.23, 0, 0],
        Vector[0, 135.35, 0],
        Vector[0, 0, 148.46]
      Lattice[74.23, 135.35, 148.46] == expected
    end
  end

  describe "#change_coords" do
    it "returns the coordinates relative to the lattice vectors" do
      lattice = Chem::Lattice.orthorombic 10, 20, 30
      lattice.change_coords(V[1, 2, 3]).should be_close V[0.1, 0.1, 0.1], 1e-15
      lattice.change_coords(V[2, 3, 15]).should be_close V[0.2, 0.15, 0.5], 1e-15

      lattice.a = 20
      lattice.change_coords(V[1, 2, 3]).should be_close V[0.05, 0.1, 0.1], 1e-15
    end
  end

  describe "#revert_coords" do
    it "returns the coordinates relative to the lattice vectors" do
      lattice = Chem::Lattice.orthorombic 20, 20, 16
      lattice.revert_coords(V[0.5, 0.65, 1]).should be_close V[10, 13, 16], 1e-15
      lattice.revert_coords(V[1.5, 0.23, 0.9]).should be_close V[30, 4.6, 14.4], 1e-15

      lattice.b /= 2
      lattice.revert_coords(V[0.5, 0.65, 1]).should be_close V[10, 6.5, 16], 1e-15

      lattice = Chem::Lattice.new(
        V[8.497, 0.007, 0.031],
        V[10.148, 42.359, 0.503],
        V[7.296, 2.286, 53.093])
      lattice.revert_coords(V[0.724, 0.04, 0.209]).should be_close V[8.083, 2.177, 11.139], 1e-3
    end
  end
end
