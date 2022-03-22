require "../spec_helper"

describe Chem::Topology::Templates do
  Chem::Topology::Templates.residue do
    description "Anything"
    name "LFG"
    structure do
      stem "N1+-C2-C3-O4-C5-C6"
      branch "C5=O7"
    end
  end

  describe "#[]" do
    it "returns a residue template by name" do
      residue_t = Chem::Topology::Templates["LFG"]
      residue_t.should be_a Chem::ResidueType
      residue_t.description.should eq "Anything"
      residue_t.name.should eq "LFG"
    end

    it "fails when no matching residue template exists" do
      expect_raises Chem::Topology::Templates::Error, "Unknown residue template" do
        Chem::Topology::Templates["ASD"]
      end
    end
  end

  describe "#[]?" do
    it "returns a residue template by name" do
      Chem::Topology::Templates["LFG"].should be_a Chem::ResidueType
    end

    it "returns nil when no matching residue template exists" do
      Chem::Topology::Templates["ASD"]?.should be_nil
    end
  end

  describe "#residue" do
    it "creates a residue template with multiple names" do
      Chem::Topology::Templates.residue do
        description "Anything"
        names "LXE", "EGR"
        structure do
          stem "C1"
        end
      end
      Chem::Topology::Templates["LXE"].should be Chem::Topology::Templates["EGR"]
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Topology::Templates::Error, "Duplicate residue template" do
        Chem::Topology::Templates.residue do
          description "Anything"
          name "LXE"
          structure do
            stem "C1"
          end
        end
      end
    end
  end
end
