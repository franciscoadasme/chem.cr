require "../../spec_helper"

describe Chem::System do
  describe ".build" do
    it "builds a system" do
      sys = Chem::System.build do
        title "Alanine"
        residue "ALA" do
          atoms "N", "CA", "C", "O", "CB"
        end
      end

      sys.title.should eq "Alanine"
      sys.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    end
  end
end
