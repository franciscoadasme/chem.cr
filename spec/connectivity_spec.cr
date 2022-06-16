require "./spec_helper"

describe Chem::Angle do
  describe ".new" do
    it "creates an angle with sorted atoms" do
      a, b, c = fake_structure.atoms
      Chem::Angle.new(a, b, c).atoms.map(&.serial).should eq({1, 2, 3})
      Chem::Angle.new(c, b, a).atoms.map(&.serial).should eq({1, 2, 3})
    end

    it "raises if duplicate atom" do
      a, b, c = fake_structure.atoms
      expect_raises ArgumentError, "Duplicate atom" do
        Chem::Angle.new(a, b, a)
      end
    end
  end

  describe "#<=>" do
    it "compares two angles" do
      a, b, c, d = fake_structure.atoms
      a1 = Chem::Angle.new(a, b, c)
      a2 = Chem::Angle.new(b, c, d)
      (a1 <=> a2).should eq -1
      (a1 <=> a1).should eq 0
      (a2 <=> a1).should eq 1
    end
  end

  describe "#==" do
    it "compares two angles" do
      a, b, c, d = fake_structure.atoms
      a1 = Chem::Angle.new(a, b, c)
      a2 = Chem::Angle.new(c, b, a)
      a3 = Chem::Angle.new(b, c, d)
      a1.should eq a1
      a1.should eq a2
      a1.should_not eq a3
    end
  end

  describe "#atoms" do
    it "returns the atoms" do
      a, b, c = fake_structure.atoms
      Chem::Angle.new(a, b, c).atoms.should eq({a, b, c})
    end
  end

  describe "#inspect" do
    it "inspect into the angle" do
      a, b, c = fake_structure.atoms
      expected = "Chem::Angle{<Atom A:ASP1:N(1)>, <Atom A:ASP1:CA(2)>, <Atom A:ASP1:C(3)>}"
      Chem::Angle.new(a, b, c).inspect.should eq expected
    end
  end

  describe "#measure" do
    it "measures the angle" do
      a, b, c = fake_structure.atoms
      Chem::Angle.new(a, b, c).measure.should be_close 110.071, 1e-3
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      a, b, c = fake_structure.atoms
      expected = "Chem::Angle{A:ASP1:N(1), A:ASP1:CA(2), A:ASP1:C(3)}"
      Chem::Angle.new(a, b, c).to_s.should eq expected
    end
  end
end

describe Chem::Dihedral do
  describe ".new" do
    it "creates a dihedral angle with sorted atoms" do
      a, b, c, d = fake_structure.atoms
      Chem::Dihedral.new(a, b, c, d).atoms.map(&.serial).should eq({1, 2, 3, 4})
      Chem::Dihedral.new(d, c, b, a).atoms.map(&.serial).should eq({1, 2, 3, 4})
    end

    it "raises if duplicate atom" do
      a, b, c, d = fake_structure.atoms
      expect_raises ArgumentError, "Duplicate atom" do
        Chem::Dihedral.new(a, b, c, a)
      end
    end
  end

  describe "#<=>" do
    it "compares two dihedral angles" do
      a, b, c, d, e = fake_structure.atoms
      a1 = Chem::Dihedral.new(a, b, c, d)
      a2 = Chem::Dihedral.new(b, c, d, e)
      (a1 <=> a2).should eq -1
      (a1 <=> a1).should eq 0
      (a2 <=> a1).should eq 1
    end
  end

  describe "#==" do
    it "compares two dihedral angles" do
      a, b, c, d, e = fake_structure.atoms
      a1 = Chem::Dihedral.new(a, b, c, d)
      a2 = Chem::Dihedral.new(d, c, b, a)
      a3 = Chem::Dihedral.new(b, c, d, e)
      a1.should eq a1
      a1.should eq a2
      a1.should_not eq a3
    end
  end

  describe "#atoms" do
    it "returns the atoms" do
      a, b, c, d = fake_structure.atoms
      Chem::Dihedral.new(a, b, c, d).atoms.should eq({a, b, c, d})
    end
  end

  describe "#inspect" do
    it "inspect into the dihedral angle" do
      a, b, c, d = fake_structure.atoms
      expected = "Chem::Dihedral{<Atom A:ASP1:N(1)>, <Atom A:ASP1:CA(2)>, \
                  <Atom A:ASP1:C(3)>, <Atom A:ASP1:O(4)>}"
      Chem::Dihedral.new(a, b, c, d).inspect.should eq expected
    end
  end

  describe "#measure" do
    it "measures the dihedral angle" do
      a, b, c, d = fake_structure.atoms
      Chem::Dihedral.new(a, b, c, d).measure.should be_close -50.435, 1e-3
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      a, b, c, d = fake_structure.atoms
      expected = "Chem::Dihedral{A:ASP1:N(1), A:ASP1:CA(2), A:ASP1:C(3), A:ASP1:O(4)}"
      Chem::Dihedral.new(a, b, c, d).to_s.should eq expected
    end
  end
end

describe Chem::Improper do
  describe ".new" do
    it "creates a improper dihedral angle with sorted atoms" do
      a, b, c, d = fake_structure.atoms
      Chem::Improper.new(a, b, c, d).atoms.map(&.serial).should eq({1, 2, 3, 4})
      Chem::Improper.new(c, b, a, d).atoms.map(&.serial).should eq({1, 2, 3, 4})
    end

    it "raises if duplicate atom" do
      a, b, c, d = fake_structure.atoms
      expect_raises ArgumentError, "Duplicate atom" do
        Chem::Improper.new(a, b, c, a)
      end
    end
  end

  describe "#<=>" do
    it "compares two improper dihedral angles" do
      a, b, c, d, e = fake_structure.atoms
      a1 = Chem::Improper.new(a, b, c, d)
      a2 = Chem::Improper.new(b, c, d, e)
      (a1 <=> a2).should eq -1
      (a1 <=> a1).should eq 0
      (a2 <=> a1).should eq 1
    end
  end

  describe "#==" do
    it "compares two improper dihedral angles" do
      a, b, c, d, e = fake_structure.atoms
      a1 = Chem::Improper.new(a, b, c, d)
      a2 = Chem::Improper.new(c, b, a, d)
      a3 = Chem::Improper.new(b, c, d, e)
      a1.should eq a1
      a1.should eq a2
      a1.should_not eq a3
    end
  end

  describe "#atoms" do
    it "returns the atoms" do
      a, b, c, d = fake_structure.atoms
      Chem::Improper.new(a, b, c, d).atoms.should eq({a, b, c, d})
    end
  end

  describe "#inspect" do
    it "inspect into the improper dihedral angle" do
      a, b, c, d = fake_structure.atoms
      expected = "Chem::Improper{<Atom A:ASP1:N(1)>, <Atom A:ASP1:CA(2)>, \
                  <Atom A:ASP1:C(3)>, <Atom A:ASP1:O(4)>}"
      Chem::Improper.new(a, b, c, d).inspect.should eq expected
    end
  end

  describe "#measure" do
    it "measures the improper dihedral angle" do
      a, b, c, d = fake_structure.atoms
      Chem::Improper.new(a, b, c, d).measure.should be_close 137.514, 1e-3
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      a, b, c, d = fake_structure.atoms
      expected = "Chem::Improper{A:ASP1:N(1), A:ASP1:CA(2), A:ASP1:C(3), A:ASP1:O(4)}"
      Chem::Improper.new(a, b, c, d).to_s.should eq expected
    end
  end
end
