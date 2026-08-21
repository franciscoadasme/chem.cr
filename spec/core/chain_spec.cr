require "../spec_helper"

describe Chem::Chain do
  describe "#new" do
    it "fails with non-alphanumeric id" do
      expect_raises ArgumentError, "Non-alphanumeric chain id" do
        Chem::Chain.new Chem::Structure.new, '['
      end
    end
  end

  describe "#<=>" do
    it "compares based on identifier" do
      chains = Chem::Structure.build do
        chain 'A'
        chain 'B'
        chain 'C'
      end.chains
      (chains[0] <=> chains[1]).<(0).should be_true
      (chains[1] <=> chains[1]).should eq 0
      (chains[2] <=> chains[1]).>(0).should be_true
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      Chem::Chain.new(Chem::Structure.new, 'K').to_s.should eq "<Chain K>"
    end
  end

  describe "#matches?" do
    it "matches by id" do
      struc = fake_structure
      struc.chains[0].matches?('A').should be_true
      struc.chains[0].matches?('B').should be_false
      struc.chains[0].matches?("AB".chars).should be_true
      struc.chains[0].matches?("BDY".chars).should be_false
      struc.chains[0].matches?('A'..'F').should be_true
      struc.chains[0].matches?('F'..'U').should be_false
    end
  end

  describe "#renumber_residues_by" do
    it "renumbers residues by the given order" do
      chain = load_file("3sgr.pdb").dig('A')
      expected = chain.residues.sort_by(&.name)
      chain.renumber_residues_by(&.name)
      chain.residues.should eq expected
    end
  end

  describe "#renumber_residues_by_connectivity" do
    it "renumbers residues by connectivity" do
      chain = load_file("cylindrin--size-09.pdb").dig 'B'
      chain.renumber_residues_by_connectivity
      chain.residues.size.should eq 18
      chain.residues.map(&.number).should eq (1..18).to_a
      chain.residues.map(&.name).should eq %w(
        LEU LYS VAL LEU GLY ASP VAL ILE GLU LEU LYS VAL LEU GLY ASP VAL ILE GLU
      )
    end
  end

  describe "#spec" do
    it "returns the chain specification" do
      fake_structure.dig('A').spec.should eq "A"
    end

    it "writes the chain specification" do
      io = IO::Memory.new
      fake_structure.dig('B').spec io
      io.to_s.should eq "B"
    end
  end
end
