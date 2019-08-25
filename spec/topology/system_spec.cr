require "../../spec_helper"

describe Chem::Structure do
  describe ".build" do
    it "builds a structure" do
      st = Chem::Structure.build do
        title "Alanine"
        residue "ALA" do
          atoms "N", "CA", "C", "O", "CB"
        end
      end

      st.title.should eq "Alanine"
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    end
  end

  describe "#wrap" do
    it "fails for non-periodic structures" do
      expect_raises Chem::Spatial::Error do
        fake_structure.wrap
      end
    end
  end
end
