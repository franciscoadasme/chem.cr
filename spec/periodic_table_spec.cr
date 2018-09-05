require "./spec_helper"

describe Chem::PeriodicTable do
  describe ".element" do
    it "returns the element by its atomic number" do
      PeriodicTable.element(6).should be PeriodicTable::Elements::C
      PeriodicTable.element(35).should be PeriodicTable::Elements::Br
    end

    it "returns the element by its symbol" do
      PeriodicTable.element("Br").should be PeriodicTable::Elements::Br
      PeriodicTable.element('C').should be PeriodicTable::Elements::C
    end

    it "returns the element by its name" do
      PeriodicTable.element(name: "Bromine").should be PeriodicTable::Elements::Br
    end

    it "returns the element by atom name" do
      PeriodicTable.element(atom_name: "O").should be PeriodicTable::Elements::O
      PeriodicTable.element(atom_name: "CA").should be PeriodicTable::Elements::C
    end

    it "fails with unknown element" do
      expect_raises(PeriodicTable::UnknownElement, /Unknown element: \w+/) do
        PeriodicTable.element 0
      end
    end
  end

  describe ".[]" do
    it "returns the element by its atomic number" do
      PeriodicTable[6].should be PeriodicTable::Elements::C
      PeriodicTable[35].should be PeriodicTable::Elements::Br
    end

    it "returns the element by its symbol" do
      PeriodicTable["Br"].should be PeriodicTable::Elements::Br
      PeriodicTable['C'].should be PeriodicTable::Elements::C
    end
  end

  describe ".[]?" do
    it "returns nil with unknown element" do
      PeriodicTable[0]?.should be_nil
    end
  end

  describe ".elements" do
    it "returns all elements" do
      PeriodicTable.elements.size.should eq 118
      PeriodicTable.elements[0].should be PeriodicTable::Elements::H
    end
  end
end
