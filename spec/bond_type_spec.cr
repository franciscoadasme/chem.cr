require "./spec_helper"

describe Chem::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")
      o = Chem::AtomTemplate.new("O", "O")
      n = Chem::AtomTemplate.new("N", "N")
      Chem::BondType.new(ca, cb).inspect.should eq "<BondType CA-CB>"
      Chem::BondType.new(c, o, :double).inspect.should eq "<BondType C=O>"
      Chem::BondType.new(c, n, :triple).inspect.should eq "<BondType C#N>"
    end
  end
end
