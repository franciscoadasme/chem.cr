require "../spec_helper"

describe Chem::Structure do
  describe ".build" do
    it "builds a structure" do
      st = Chem::Structure.build do
        title "Alanine"
        residue "ALA" do
          %w(N CA C O CB).each { |name| atom name, Vector.origin }
        end
      end

      st.title.should eq "Alanine"
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    end
  end
end
