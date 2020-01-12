require "../spec_helper"

describe Topology::AtomType do
  describe "#inspect" do
    it "returns a string representation" do
      Topology::AtomType.new("CA").inspect.should eq "<AtomType CA>"
      Topology::AtomType.new("NZ", formal_charge: 1).inspect.should eq "<AtomType NZ+>"
      Topology::AtomType.new("SG", valency: 1).inspect.should eq "<AtomType SG(1)>"
    end
  end

  describe "#to_s" do
    it "returns atom name" do
      Topology::AtomType.new("CA").to_s.should eq "CA"
    end

    it "returns atom name plus charge sign when charge is not zero" do
      Topology::AtomType.new("NZ", formal_charge: 1).to_s.should eq "NZ+"
      Topology::AtomType.new("OE1", formal_charge: -1).to_s.should eq "OE1-"
      Topology::AtomType.new("NA", formal_charge: 2).to_s.should eq "NA+2"
      Topology::AtomType.new("UK", formal_charge: -5).to_s.should eq "UK-5"
    end

    it "returns atom name plus valency when its not nominal" do
      Topology::AtomType.new("SG", valency: 1).to_s.should eq "SG(1)"
    end
  end
end

describe Topology::BondType do
  describe "#inspect" do
    it "returns a string representation" do
      Topology::BondType.new("CA", "CB").inspect.should eq "<BondType CA-CB>"
      Topology::BondType.new("C", "O", order: 2).inspect.should eq "<BondType C=O>"
      Topology::BondType.new("C", "N", order: 3).inspect.should eq "<BondType C#N>"
    end
  end
end

describe Topology::ResidueType do
  describe "#inspect" do
    it "returns a string representation" do
      Topology::ResidueType.build do
        name "O2"
        description "Molecular oxygen"
        main "O=O"
      end.inspect.should eq "<ResidueType O2>"

      Topology::ResidueType.build(:solvent) do
        name "HOH"
        description "Water"
        main "O"
      end.inspect.should eq "<ResidueType HOH, solvent>"

      Topology::ResidueType.build(:protein) do
        description "Glycine"
        name "GLY"
        code 'G'
        remove_atom "HA"
      end.inspect.should eq "<ResidueType GLY(G), protein>"
    end
  end
end
