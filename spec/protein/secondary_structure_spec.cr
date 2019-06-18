require "../spec_helper"

describe Chem::Protein::SecondaryStructure do
  describe ".[]?" do
    it "returns the secondary structure member from the one-letter code" do
      Chem::Protein::SecondaryStructure['H']?.to_s.should eq "HelixAlpha"
      Chem::Protein::SecondaryStructure['G']?.to_s.should eq "Helix3_10"
      Chem::Protein::SecondaryStructure['I']?.to_s.should eq "HelixPi"
      Chem::Protein::SecondaryStructure['E']?.to_s.should eq "BetaStrand"
      Chem::Protein::SecondaryStructure['B']?.to_s.should eq "BetaBridge"
      Chem::Protein::SecondaryStructure['T']?.to_s.should eq "Turn"
      Chem::Protein::SecondaryStructure['C']?.to_s.should eq "None"
      Chem::Protein::SecondaryStructure['0']?.to_s.should eq "None"
    end

    it "returns nil when code is invalid" do
      Chem::Protein::SecondaryStructure['F']?.should be_nil
    end
  end

  describe ".[]" do
    it "fails when code is invalid" do
      expect_raises Exception, "Unknown secondary structure code: F" do
        Chem::Protein::SecondaryStructure['F']
      end
    end
  end
end
