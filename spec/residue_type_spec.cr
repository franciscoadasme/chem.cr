require "./spec_helper"

describe Chem::ResidueType do
  Chem::ResidueType.register do
    name "LFG"
    structure "[N1H3+]-C2-C3-O4-C5(-C6)=O7"
    root "C5"
  end

  describe ".fetch" do
    it "returns a residue type by name" do
      residue_t = Chem::ResidueType.fetch("LFG")
      residue_t.should be_a Chem::ResidueType
      residue_t.name.should eq "LFG"
    end

    it "raises if residue type does not exist" do
      expect_raises Chem::Error, "Unknown residue type ASD" do
        Chem::ResidueType.fetch("ASD")
      end
    end

    it "returns block's return value if residue type does not exist" do
      Chem::ResidueType.fetch("ASD") { nil }.should be_nil
    end
  end

  describe ".register" do
    it "creates a residue template with multiple names" do
      Chem::ResidueType.register do
        name "LXE", "EGR"
        structure "C1"
      end
      Chem::ResidueType.fetch("LXE").should be Chem::ResidueType.fetch("EGR")
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Error, "LXE residue type already exists" do
        Chem::ResidueType.register do
          name "LXE"
          structure "C1"
          root "C1"
        end
      end
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueType.build do
        name "O2"
        structure "O1=O2"
        root "O1"
      end.inspect.should eq "<ResidueType O2>"

      Chem::ResidueType.build do
        name "HOH"
        kind :solvent
        structure "O"
      end.inspect.should eq "<ResidueType HOH, solvent>"

      Chem::ResidueType.build do
        name "GLY"
        code 'G'
        kind :protein
        structure "N(-H)-CA(-C=O)"
      end.inspect.should eq "<ResidueType GLY(G), protein>"
    end
  end
end
