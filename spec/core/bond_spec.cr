require "../spec_helper"

describe Chem::Bond do
  st = fake_structure
  glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

  describe "#==" do
    it "returns true when the atoms are in the same order" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_cd, glu_oe1)
    end

    it "returns true when the atoms are in the inverse order" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_oe1, glu_cd)
    end

    it "returns true when the atoms are the same but the bond orders are different" do
      Chem::Bond.new(glu_cd, glu_oe1).should eq Chem::Bond.new(glu_cd, glu_oe1, :double)
    end

    it "returns false when the atoms are not the same" do
      Chem::Bond.new(glu_cd, glu_oe1).should_not eq Chem::Bond.new(glu_cd, glu_oe2)
    end
  end

  describe "#includes?" do
    it "returns true when the bond includes the given atom" do
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_cd).should be_true
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_oe1).should be_true
    end

    it "returns false when the bond does not include the given atom" do
      Chem::Bond.new(glu_cd, glu_oe1).includes?(glu_oe2).should be_false
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      structure = Chem::Structure.build do
        residue "ICN", 91
        atom :I, vec3(-1, 0, 0)
        atom :C, vec3(0, 0, 0)
        atom :P, vec3(1, 0, 0)
        atom :O, vec3(2, 0, 0)
        bond "I1", "C1"
        bond "C1", "P1", order: 3
        bond "P1", "O1", order: 2
      end
      bond_map = structure.bonds.index_by { |bond| {bond[0].name, bond[1].name} }
      bond_map[{"I1", "C1"}].inspect.should eq "<Bond A:ICN91:I1(1)-A:ICN91:C1(2)>"
      bond_map[{"C1", "P1"}].inspect.should eq "<Bond A:ICN91:C1(2)#A:ICN91:P1(3)>"
      bond_map[{"P1", "O1"}].inspect.should eq "<Bond A:ICN91:P1(3)=A:ICN91:O1(4)>"
    end
  end

  describe "#order" do
    it "returns order as a number" do
      Chem::Bond.new(glu_cd, glu_oe1).order.should eq 1
      Chem::Bond.new(glu_cd, glu_oe1, :zero).order.should eq 0
      Chem::Bond.new(glu_cd, glu_oe1, :double).order.should eq 2
      Chem::Bond.new(glu_cd, glu_oe1, :triple).order.should eq 3
      Chem::Bond.new(glu_cd, glu_oe1, :dative).order.should eq 1
    end
  end

  describe "#order=" do
    bond = Chem::Bond.new glu_cd, glu_oe1

    it "changes bond order" do
      bond.kind.should eq Chem::Bond::Kind::Single
      bond.order.should eq 1

      bond.order = 2
      bond.kind.should eq Chem::Bond::Kind::Double
      bond.order.should eq 2

      bond.order = 3
      bond.kind.should eq Chem::Bond::Kind::Triple
      bond.order.should eq 3

      bond.order = 0
      bond.kind.should eq Chem::Bond::Kind::Zero
      bond.order.should eq 0
    end

    it "fails when order is invalid" do
      expect_raises Chem::Error, "Bond order (5) is invalid" do
        bond.order = 5
      end
    end
  end

  describe "#other" do
    it "returns the other atom" do
      bond = Chem::Bond.new glu_cd, glu_oe1
      bond.other(glu_cd).should be glu_oe1
      bond.other(glu_oe1).should be glu_cd
    end

    it "fails when the bond does not include the given atom" do
      expect_raises Chem::Error, "Bond doesn't include atom 9" do
        Chem::Bond.new(glu_cd, glu_oe1).other glu_oe2
      end
    end
  end
end
