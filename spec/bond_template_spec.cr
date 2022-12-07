require "./spec_helper"

describe Chem::BondTemplate do
  describe "#==" do
    it "tells if two bond templates are equal" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")
      Chem::BondTemplate.new(ca, c).should eq Chem::BondTemplate.new(ca, c)
      Chem::BondTemplate.new(ca, c).should eq Chem::BondTemplate.new(c, ca)
      Chem::BondTemplate.new(ca, c).should_not eq Chem::BondTemplate.new(ca, cb)
    end
  end

  describe "#includes" do
    it "tells if two bond templates are equal" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")
      bond_t = Chem::BondTemplate.new(ca, c)

      bond_t.includes?(ca).should be_true
      bond_t.includes?(c).should be_true
      bond_t.includes?(cb).should be_false

      # using atom names
      bond_t.includes?("CA").should be_true
      bond_t.includes?("C").should be_true
      bond_t.includes?("CB").should be_false
    end
  end

  describe "#other" do
    it "raises if unknown atom" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")

      bond_t = Chem::BondTemplate.new(ca, c)
      expect_raises(KeyError, "<AtomTemplate CB> not found in <BondTemplate CA-C>") do
        bond_t.other(cb)
      end

      # using names
      expect_raises(KeyError, "Atom \"CX\" not found in <BondTemplate CA-C>") do
        bond_t.other("CX")
      end
    end
  end

  describe "#other?" do
    it "returns the bonded atom" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")

      bond_t = Chem::BondTemplate.new(ca, c)
      bond_t.other?(ca).should eq c
      bond_t.other?(c).should eq ca

      # using atom names
      bond_t.other?("CA").should eq c
      bond_t.other?("C").should eq ca
    end

    it "returns nil if unknown atom" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")

      bond_t = Chem::BondTemplate.new(ca, c)
      bond_t.other?(cb).should be_nil
      bond_t.other?("CX").should be_nil
    end
  end

  describe "#reverse" do
    c = Chem::AtomTemplate.new("C", "C")
    ca = Chem::AtomTemplate.new("CA", "C")
    bond_t = Chem::BondTemplate.new(ca, c)
    bond_t.reverse.should eq bond_t
    bond_t.reverse.atoms.map(&.name).to_a.should eq %w(C CA)
  end

  describe "#to_s" do
    it "returns a string representation" do
      c = Chem::AtomTemplate.new("C", "C")
      ca = Chem::AtomTemplate.new("CA", "C")
      cb = Chem::AtomTemplate.new("CB", "C")
      o = Chem::AtomTemplate.new("O", "O")
      n = Chem::AtomTemplate.new("N", "N")
      Chem::BondTemplate.new(ca, cb).to_s.should eq "<BondTemplate CA-CB>"
      Chem::BondTemplate.new(c, o, :double).to_s.should eq "<BondTemplate C=O>"
      Chem::BondTemplate.new(c, n, :triple).to_s.should eq "<BondTemplate C#N>"
    end
  end
end
