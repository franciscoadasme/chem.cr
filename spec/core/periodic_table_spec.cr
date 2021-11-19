require "../spec_helper"

describe Chem::PeriodicTable do
  describe ".[]" do
    it "fails with unknown element" do
      expect_raises(Chem::Error, /Unknown element: \w+/) do
        Chem::PeriodicTable[0]
      end
    end
  end

  describe ".[]?" do
    it "returns the element by its atomic number" do
      Chem::PeriodicTable[6]?.should be Chem::PeriodicTable::C
      Chem::PeriodicTable[6]?.try(&.atomic_number).should eq 6
      Chem::PeriodicTable[35]?.should be Chem::PeriodicTable::Br
      Chem::PeriodicTable[35]?.try(&.atomic_number).should eq 35
    end

    it "returns the element by its symbol" do
      Chem::PeriodicTable["Br"]?.should be Chem::PeriodicTable::Br
      Chem::PeriodicTable['C']?.should be Chem::PeriodicTable::C
    end

    it "returns the element by its name" do
      Chem::PeriodicTable[name: "Bromine"]?.should be Chem::PeriodicTable::Br
    end

    it "returns the element by atom name" do
      Chem::PeriodicTable[atom_name: "O"]?.should be Chem::PeriodicTable::O
      Chem::PeriodicTable[atom_name: "CA"]?.should be Chem::PeriodicTable::C
    end

    it "returns nil with unknown element" do
      Chem::PeriodicTable[0]?.should be_nil
    end
  end

  describe ".elements" do
    it "returns all elements" do
      Chem::PeriodicTable.elements.size.should eq 118
      Chem::PeriodicTable.elements[0].should be Chem::PeriodicTable::H
      Chem::PeriodicTable.elements[-1].should be Chem::PeriodicTable::Uuo
    end
  end
end
