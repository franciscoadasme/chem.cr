require "./spec_helper"

describe Chem::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      c = Chem::AtomType.new("C", "C")
      ca = Chem::AtomType.new("CA", "C")
      cb = Chem::AtomType.new("CB", "C")
      o = Chem::AtomType.new("O", "O")
      n = Chem::AtomType.new("N", "N")
      Chem::BondType.new(ca, cb).inspect.should eq "<BondType CA-CB>"
      Chem::BondType.new(c, o, :double).inspect.should eq "<BondType C=O>"
      Chem::BondType.new(c, n, :triple).inspect.should eq "<BondType C#N>"
    end
  end
end
