require "./spec_helper"

describe Chem::AtomTemplate do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::AtomTemplate.new("CA", "C").inspect.should eq "<AtomTemplate CA>"
      Chem::AtomTemplate.new("NZ", "N", formal_charge: 1).inspect.should eq "<AtomTemplate NZ+>"
    end
  end

  describe "#to_s" do
    it "returns atom name" do
      Chem::AtomTemplate.new("CA", "C").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::AtomTemplate.new("NZ", "N", formal_charge: 1).to_s.should eq "NZ+"
      Chem::AtomTemplate.new("OE1", "O", formal_charge: -1).to_s.should eq "OE1-"
      Chem::AtomTemplate.new("NA", "N", formal_charge: 2).to_s.should eq "NA+2"
      Chem::AtomTemplate.new("UK", "C", formal_charge: -5).to_s.should eq "UK-5"
    end
  end
end
