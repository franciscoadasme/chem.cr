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
      lattice = Lattice.new({74.23, 135.35, 148.46}, {90.0, 90.0, 90.0}, "P 21 21 21")
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
      lattice.scale_factor.should eq 1
      lattice.space_group.should eq "P 21 21 21"
    end

    it "succeeds with sizes (orthorombic box)" do
      lattice = Lattice.orthorombic 74.23, 135.35, 148.46
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
      lattice.scale_factor.should eq 1
      lattice.space_group.should eq "P 1"
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
end
