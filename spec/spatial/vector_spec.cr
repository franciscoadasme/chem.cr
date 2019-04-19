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

  describe "#abs" do
    it "returns the element-wise absolute value of the vector" do
      V[-1, 5, 4].abs.should eq V[1, 5, 4]
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

  describe "#floor" do
    it "returns the element-wise floor value of the vector" do
      V[-1.5234, 2.31, 4.001].floor.should eq V[-2, 2, 4]
    end
  end

  describe "#inv" do
    it "returns the inverse vector" do
      v1.inv.should eq Vector[-3, -4, 0]
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation of a vector" do
      V[2.5, 1, 8.4].inspect.should eq "Vector[2.5, 1.0, 8.4]"
    end
  end

  describe "#map" do
    it "returns the element-wise map operation of the vector" do
      V[-5, 1, 0].map(&.**(2)).should eq V[25, 1, 0]
    end
  end

  describe "#map_with_index" do
    it "returns the element-wise map operation of the vector" do
      V[2, 75, 2].map_with_index { |value, i| value + i**2 }.should eq V[2, 76, 6]
    end
  end

  describe "#norm" do
    it "returns the norm of the vector" do
      Vector.origin.norm.should eq 0
      v1.norm.should eq 5
      v1.inv.norm.should eq 5
      Vector[0.6, 0.8, 0].norm.should eq 1
    end
  end

  describe "#normalize" do
    it "returns the unit vector" do
      v1.normalize.should eq Vector[0.6, 0.8, 0]
    end
  end

  describe "#resize" do
    it "resizes a vector to an arbitrary size" do
      V[1, 0, 0].resize(to: 5).should eq V[5, 0, 0]
      (V[1, 1, 0] * 4.2).resize(to: 1).should eq V[Math.sqrt(0.5), Math.sqrt(0.5), 0]
    end

    it "resizes a vector by the given amount" do
      V[1, 0, 0].resize(by: 2).should eq V[3, 0, 0]
      V[0.34, 0.16, 0.1].resize(by: 2.5).size.should eq 2.888844441904472
    end
  end

  describe "#rotate" do
    it "rotates a vector" do
      V[1, 0, 0].rotate(about: V[0, 0, 1], by: 90).should be_close V[0, 1, 0], 1e-15
      V[1, 2, 0].rotate(about: V[0, 0, -1], by: 60).should be_close V[2.23, 0.13, 0], 1e-2
      V[0, 1, 0].rotate(about: V[1, 1, 1], by: 120).should be_close V[0, 0, 1], 1e-15
    end
  end

  describe "#round" do
    it "rounds a vector" do
      V[-1.4, 2.50001, 9.2].round.should eq V[-1, 3, 9]
    end
  end

  describe "#to_a" do
    it "returns an array" do
      v1.to_a.should eq [3, 4, 0]
    end
  end

  describe "#to_m" do
    it "returns a column matrix" do
      V[3, 1, 5].to_m.should eq Chem::Linalg::Matrix[[3], [1], [5]]
    end
  end

  describe "#to_s" do
    it "returns a string representation of a vector" do
      V[2.5, 1, 8.4].to_s.should eq "[2.5 1.0 8.4]"
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
      v1.inv.zero?.should be_false
    end
  end
end
