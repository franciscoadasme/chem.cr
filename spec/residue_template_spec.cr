require "./spec_helper"

describe Chem::ResidueTemplate do
  Chem::ResidueTemplate.register do
    name "LFG"
    structure "[N1H3+]-C2-C3-O4-C5(-C6)=O7"
    root "C5"
  end

  describe ".fetch" do
    it "returns a residue template by name" do
      residue_t = Chem::ResidueTemplate.fetch("LFG")
      residue_t.should be_a Chem::ResidueTemplate
      residue_t.name.should eq "LFG"
    end

    it "raises if residue template does not exist" do
      expect_raises Chem::Error, "Unknown residue template ASD" do
        Chem::ResidueTemplate.fetch("ASD")
      end
    end

    it "returns block's return value if residue template does not exist" do
      Chem::ResidueTemplate.fetch("ASD") { nil }.should be_nil
    end
  end

  describe ".register" do
    it "creates a residue template with multiple names" do
      Chem::ResidueTemplate.register do
        name "LXE", "EGR"
        structure "C1"
      end
      Chem::ResidueTemplate.fetch("LXE").should be Chem::ResidueTemplate.fetch("EGR")
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Error, "LXE residue template already exists" do
        Chem::ResidueTemplate.register do
          name "LXE"
          structure "C1"
          root "C1"
        end
      end
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueTemplate.build do
        name "O2"
        structure "O1=O2"
        root "O1"
      end.inspect.should eq "<ResidueTemplate O2>"

      Chem::ResidueTemplate.build do
        name "HOH"
        type :solvent
        structure "O"
      end.inspect.should eq "<ResidueTemplate HOH, solvent>"

      Chem::ResidueTemplate.build do
        name "GLY"
        code 'G'
        type :protein
        structure "N(-H)-CA(-C=O)"
      end.inspect.should eq "<ResidueTemplate GLY(G), protein>"
    end
  end
end
