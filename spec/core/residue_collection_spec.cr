require "../spec_helper"

describe Chem::ResidueCollection do
  describe "#each_residue" do
    it "iterates over each residue when called with block" do
      ary = [] of String
      fake_structure.each_residue { |residue| ary << residue.name }
      ary.should eq ["ASP", "PHE", "SER"]
    end

    it "returns an iterator when called without block" do
      fake_structure.each_residue.should be_a Iterator(Chem::Residue)
    end
  end

  describe "#n_residues" do
    it "returns the number of residues" do
      fake_structure.n_residues.should eq 3
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      fake_structure.residues.should be_a Chem::ResidueView
    end
  end
end
