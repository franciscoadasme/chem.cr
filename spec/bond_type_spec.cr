require "./spec_helper"

describe Chem::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::BondType.new("CA", "CB").inspect.should eq "<BondType CA-CB>"
      Chem::BondType.new("C", "O", order: 2).inspect.should eq "<BondType C=O>"
      Chem::BondType.new("C", "N", order: 3).inspect.should eq "<BondType C#N>"
    end
  end
end
