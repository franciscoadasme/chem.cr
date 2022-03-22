require "./spec_helper"

describe Chem::AtomType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::AtomType.new("CA").inspect.should eq "<AtomType CA>"
      Chem::AtomType.new("NZ", formal_charge: 1).inspect.should eq "<AtomType NZ+>"
      Chem::AtomType.new("SG", valency: 1).inspect.should eq "<AtomType SG(1)>"
    end
  end

  describe "#to_s" do
    it "returns atom name" do
      Chem::AtomType.new("CA").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Chem::AtomType.new("NZ", formal_charge: 1).to_s.should eq "NZ+"
      Chem::AtomType.new("OE1", formal_charge: -1).to_s.should eq "OE1-"
      Chem::AtomType.new("NA", formal_charge: 2).to_s.should eq "NA+2"
      Chem::AtomType.new("UK", formal_charge: -5).to_s.should eq "UK-5"
    end

    it "returns atom name plus valency when its not nominal" do
      Chem::AtomType.new("SG", valency: 1).to_s.should eq "SG(1)"
    end
  end
end

describe Chem::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::BondType.new("CA", "CB").inspect.should eq "<BondType CA-CB>"
      Chem::BondType.new("C", "O", order: 2).inspect.should eq "<BondType C=O>"
      Chem::BondType.new("C", "N", order: 3).inspect.should eq "<BondType C#N>"
    end
  end
end

describe Chem::ResidueType do
  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueType.build do
        name "O2"
        description "Molecular oxygen"
        structure "O=O"
      end.inspect.should eq "<ResidueType O2>"

      Chem::ResidueType.build do
        name "HOH"
        kind :solvent
        description "Water"
        structure "O"
      end.inspect.should eq "<ResidueType HOH, solvent>"

      Chem::ResidueType.build do
        description "Glycine"
        name "GLY"
        code 'G'
        kind :protein
        structure do
          backbone
          remove_atom "HA"
        end
      end.inspect.should eq "<ResidueType GLY(G), protein>"
    end
  end
end
