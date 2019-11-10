require "./spec_helper"

describe Chem::PeriodicTable do
  describe ".[]" do
    it "fails with unknown element" do
      expect_raises(Chem::Error, /Unknown element: \w+/) do
        PeriodicTable[0]
      end
    end
  end

  describe ".[]?" do
    it "returns the element by its atomic number" do
      PeriodicTable[6]?.should be PeriodicTable::C
      PeriodicTable[6]?.try(&.atomic_number).should eq 6
      PeriodicTable[35]?.should be PeriodicTable::Br
      PeriodicTable[35]?.try(&.atomic_number).should eq 35
    end

    it "returns the element by its symbol" do
      PeriodicTable["Br"]?.should be PeriodicTable::Br
      PeriodicTable['C']?.should be PeriodicTable::C
    end

    it "returns the element by its name" do
      PeriodicTable[name: "Bromine"]?.should be PeriodicTable::Br
    end

    it "returns the element by atom name" do
      PeriodicTable[atom_name: "O"]?.should be PeriodicTable::O
      PeriodicTable[atom_name: "CA"]?.should be PeriodicTable::C
    end

    it "returns nil with unknown element" do
      PeriodicTable[0]?.should be_nil
    end
  end

  describe ".elements" do
    it "returns all elements" do
      PeriodicTable.elements.size.should eq 118
      PeriodicTable.elements[0].should be PeriodicTable::H
      PeriodicTable.elements[-1].should be PeriodicTable::Uuo
    end
  end
end
