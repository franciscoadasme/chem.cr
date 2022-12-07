require "./spec_helper"

describe Chem::AtomTemplate do
  describe "#to_s" do
    it "returns string representation" do
      Chem::AtomTemplate.new("CA", "C").to_s.should eq "<AtomTemplate CA>"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::AtomTemplate.new("NZ", "N", formal_charge: 1).to_s.should eq "<AtomTemplate NZ+>"
      Chem::AtomTemplate.new("OE1", "O", formal_charge: -1).to_s.should eq "<AtomTemplate OE1->"
      Chem::AtomTemplate.new("NA", "N", formal_charge: 2).to_s.should eq "<AtomTemplate NA+2>"
      Chem::AtomTemplate.new("UK", "C", formal_charge: -5).to_s.should eq "<AtomTemplate UK-5>"
    end
  end
end
