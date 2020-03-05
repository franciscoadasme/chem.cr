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

  describe "#renumber_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file "5e5v--unwrapped.poscar", topology: :guess
      structure.renumber_by_connectivity

      chains = structure.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].previous.should be_nil
      chains[0].residues[3].previous.try(&.name).should eq "GLY"
      chains[0].residues[3].next.try(&.name).should eq "ILE"
      chains[0].residues[-1].next.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      structure = load_file "hlx_gly.poscar", topology: :renumber

      structure.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.next.should eq b
        b.previous.should eq a
      end
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      fake_structure.residues.should be_a Chem::ResidueView
    end
  end
end
