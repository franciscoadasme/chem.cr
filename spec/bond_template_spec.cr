require "./spec_helper"

describe Chem::BondTemplate do
  describe "#inspect" do
    it "returns a string representation" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")
      o = Chem::AtomTemplate.new("O", "O")
      n = Chem::AtomTemplate.new("N", "N")
      Chem::BondTemplate.new(ca, cb).inspect.should eq "<BondTemplate CA-CB>"
      Chem::BondTemplate.new(c, o, :double).inspect.should eq "<BondTemplate C=O>"
      Chem::BondTemplate.new(c, n, :triple).inspect.should eq "<BondTemplate C#N>"
    end
  end
end
