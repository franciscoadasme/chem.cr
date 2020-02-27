require "../spec_helper"

describe Chem::Chain do
  describe "#new" do
    it "fails with non-alphanumeric id" do
      expect_raises ArgumentError, "Non-alphanumeric chain id" do
        Chain.new '[', Structure.new
      end
    end
  end

  describe "#<=>" do
    it "compares based on identifier" do
      chains = Structure.build do
        chain 'A'
        chain 'B'
        chain 'C'
      end.chains
      (chains[0] <=> chains[1]).<(0).should be_true
      (chains[1] <=> chains[1]).should eq 0
      (chains[2] <=> chains[1]).>(0).should be_true
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      Chain.new('K', Structure.new).inspect.should eq "<Chain K>"
    end
  end
end
