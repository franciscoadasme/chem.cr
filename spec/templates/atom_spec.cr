require "../spec_helper"

describe Chem::Templates::Atom do
  describe "#to_s" do
    it "returns string representation" do
      Chem::Templates::Atom.new("CA", "C").to_s.should eq "<Templates::Atom CA>"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::Templates::Atom.new("NZ", "N", 1).to_s.should eq "<Templates::Atom NZ+>"
      Chem::Templates::Atom.new("OE1", "O", -1).to_s.should eq "<Templates::Atom OE1->"
      Chem::Templates::Atom.new("NA", "N", 2).to_s.should eq "<Templates::Atom NA+2>"
      Chem::Templates::Atom.new("UK", "C", -5).to_s.should eq "<Templates::Atom UK-5>"
    end
  end
end
