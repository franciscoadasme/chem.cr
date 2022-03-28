require "./spec_helper"

describe Chem::AtomType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::AtomType.new("CA", "C").inspect.should eq "<AtomType CA>"
      Chem::AtomType.new("NZ", "N", formal_charge: 1).inspect.should eq "<AtomType NZ+>"
    end
  end

  describe "#to_s" do
    it "returns atom name" do
      Chem::AtomType.new("CA", "C").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::AtomType.new("NZ", "N", formal_charge: 1).to_s.should eq "NZ+"
      Chem::AtomType.new("OE1", "O", formal_charge: -1).to_s.should eq "OE1-"
      Chem::AtomType.new("NA", "N", formal_charge: 2).to_s.should eq "NA+2"
      Chem::AtomType.new("UK", "C", formal_charge: -5).to_s.should eq "UK-5"
    end
  end
end
