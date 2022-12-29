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
        bond "C1", "P1", :triple
        bond "P1", "O1", :double
      end
      bond_map = structure.bonds.index_by &.atoms.map(&.name)
      bond_map[{"I1", "C1"}].inspect.should eq "<Bond A:ICN91:I1(1)-A:ICN91:C1(2)>"
      bond_map[{"C1", "P1"}].inspect.should eq "<Bond A:ICN91:C1(2)#A:ICN91:P1(3)>"
      bond_map[{"P1", "O1"}].inspect.should eq "<Bond A:ICN91:P1(3)=A:ICN91:O1(4)>"
    end
  end

  describe "#order" do
    it "returns order as a number" do
      Chem::Bond.new(glu_cd, glu_oe1).order.to_i.should eq 1
      Chem::Bond.new(glu_cd, glu_oe1, :zero).order.to_i.should eq 0
      Chem::Bond.new(glu_cd, glu_oe1, :double).order.to_i.should eq 2
      Chem::Bond.new(glu_cd, glu_oe1, :triple).order.to_i.should eq 3
    end
  end

  describe "#other" do
    it "returns the other atom" do
      bond = Chem::Bond.new glu_cd, glu_oe1
      bond.other(glu_cd).should be glu_oe1
      bond.other(glu_oe1).should be glu_cd
    end

    it "fails when the bond does not include the given atom" do
      expect_raises Chem::Error, "Bond doesn't include <Atom A:PHE2:N(9)>" do
        Chem::Bond.new(glu_cd, glu_oe1).other glu_oe2
      end
    end
  end

  describe "#matches?" do
    it "tells if a bond matches a template" do
      structure = Chem::Structure.build do |builder|
        builder.atom "C1", vec3(0, 0, 0)
        builder.atom "O1", vec3(0, 0, 0)
        builder.bond "C1", "O1"
      end
      bond = structure.bonds[0]
      # uses Bond#matches?(Templates::Bond) internally
      bond.should match({ {"C1", "C"}, {"O1", "O"} })
      bond.should_not match({ {"C1", "C"}, {"O1", "O"}, :double })
      bond.should_not match({ {"C2", "C"}, {"O1", "O"} })
      bond.should_not match({ {"C1", "C"}, {"O1", "C"} })
    end
  end
end
