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

  describe "#dig" do
    structure = fake_structure

    it "returns a chain" do
      structure.dig('A').id.should eq 'A'
    end

    it "returns a residue" do
      structure.dig('A', 2).name.should eq "PHE"
      structure.dig('A', 2, nil).name.should eq "PHE"
    end

    it "returns an atom" do
      structure.dig('A', 2, "CA").name.should eq "CA"
      structure.dig('A', 2, nil, "CA").name.should eq "CA"
    end

    it "fails when index is invalid" do
      expect_raises(KeyError) { structure.dig 'C' }
      expect_raises(KeyError) { structure.dig 'A', 25 }
      expect_raises(KeyError) { structure.dig 'A', 2, "OH" }
    end
  end

  describe "#dig?" do
    structure = fake_structure

    it "returns nil when index is invalid" do
      structure.dig?('C').should be_nil
      structure.dig?('A', 25).should be_nil
      structure.dig?('A', 2, "OH").should be_nil
    end
  end

  describe "#periodic?" do
    it "returns true when a structure has a lattice" do
      Chem::Structure.build { lattice 10, 20, 30 }.periodic?.should be_true
    end

    it "returns false when a structure does not have a lattice" do
      Chem::Structure.new.periodic?.should be_false
    end
  end
end
