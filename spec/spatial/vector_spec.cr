require "../spec_helper"

describe Chem::Spatial::Vector do
  v1 = Vector[3.0, 4.0, 0.0]
  v2 = Vector[1.0, 2.0, 3.0]

  describe ".[]" do
    it "returns a vector with the given components" do
      Vector[1, 2, 3].should eq Vector.new(1, 2, 3)
    end
  end

  describe ".zero" do
    it "returns a vector zero" do
      Vector.zero.should eq Vector[0, 0, 0]
    end
  end

  describe "#[]" do
    it "returns a vector component value when 0 <= i < 3" do
      v1[0].should eq 3
      v1[1].should eq 4
      v1[2].should eq 0
    end

    it "fails when i < 0 or i > 2" do
      expect_raises(IndexError) { v1[3] }
      expect_raises(IndexError) { v1[-1] }
    end
  end

  describe "#==" do
    it "compares vectors" do
      v1.should_not eq v2
      v1.should eq v1
      v1.should eq Vector[3.0, 4.0, 0.0]
    end
  end

  describe "#+" do
    it "returns the arithmetic addition between vectors" do
      (v1 + v2).should eq Vector[4, 6, 3]
    end

    it "returns the arithmetic addition with a 3-sized tuple" do
      (v1 + {1, 2, 3}).should eq Vector[4, 6, 3]
    end
  end

  describe "#-" do
    it "returns the inverse vector" do
      (-v1).should eq Vector[-3, -4, 0]
    end

    it "returns the subtraction between vectors" do
      (v1 - v2).should eq Vector[2, 2, -3]
    end

    it "returns the subtraction with a 3-sized tuple" do
      (v1 - {1, 2, 3}).should eq Vector[2, 2, -3]
    end
  end

  describe "#*" do
    it "returns the multiplication with a number" do
      (v1 * 3).should eq Vector[9, 12, 0]
    end
  end

  describe "#/" do
    it "returns the division by a number" do
      (v1 / 5).should eq Vector[0.6, 0.8, 0]
    end
  end

  describe "#cross" do
    it "returns the cross product between two vectors" do
      Vector[1, 0, 0].cross(Vector[0, 1, 0]).should eq Vector[0, 0, 1]
      Vector[2, 3, 4].cross(Vector[5, 6, 7]).should eq Vector[-3, 6, -3]
    end
  end

  describe "#dot" do
    it "returns the dot product between two vectors" do
      Vector[3, 4, 0].dot(Vector[4, 4, 2]).should eq 28
    end
  end

  describe "#inverse" do
    it "returns the inverse vector" do
      v1.inverse.should eq Vector[-3, -4, 0]
    end
  end

  describe "#magnitude" do
    it "returns the magnitude of the vector" do
      Vector.origin.magnitude.should eq 0
      v1.magnitude.should eq 5
      v1.inverse.magnitude.should eq 5
      Vector[0.6, 0.8, 0].magnitude.should eq 1
    end
  end

  describe "#normalize" do
    it "returns the unit vector" do
      v1.normalize.should eq Vector[0.6, 0.8, 0]
    end
  end

  describe "#to_a" do
    it "returns an array" do
      v1.to_a.should eq [3, 4, 0]
    end
  end

  describe "#to_t" do
    it "returns a 3-sized tuple" do
      v1.to_t.should eq({3, 4, 0})
    end
  end

  describe "#zero?" do
    it "returns whether the vector is zero" do
      Vector.zero.zero?.should be_true
      v1.zero?.should be_false
      v1.inverse.zero?.should be_false
    end
  end
end