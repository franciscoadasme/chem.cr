require "../spec_helper"

describe Chem::AtomView do
  atoms = fake_structure.atoms

  describe "#[]" do
    it "gets atom by zero-based index" do
      atoms[4].name.should eq "CB"
    end

    it "gets atom by serial number" do
      atoms[serial: 5].name.should eq "CB"
    end
  end

  describe "#each_residue" do
    it "yields each residue" do
      residues = [] of Chem::Residue
      atoms.each_residue { |residue| residues << residue }
      residues.map(&.name).should eq %w(ASP PHE SER)
      residues.map(&.number).should eq [1, 2, 1]
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      atoms.size.should eq 25
    end
  end
end
