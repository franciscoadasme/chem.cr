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
    it "returns the element-wise arithmetic addition with a number" do
      (V[1, 2, 3] + 5).should eq V[6, 7, 8]
    end

    it "returns the arithmetic addition between vectors" do
      (v1 + v2).should eq Vector[4, 6, 3]
    end

    it "returns the arithmetic addition with a 3-sized tuple" do
      (v1 + {1, 2, 3}).should eq Vector[4, 6, 3]
    end

    it "sums a vector and a size" do
      (V[1, 2, 3] + S[3, 2, 1]).should eq V[4, 4, 4]
    end
  end

  describe "#-" do
    it "returns the inverse vector" do
      (-v1).should eq Vector[-3, -4, 0]
    end

    it "returns the element-wise subtraction with a number" do
      (V[3, 9, 123] - 5).should eq V[-2, 4, 118]
    end

    it "returns the subtraction between vectors" do
      (v1 - v2).should eq Vector[2, 2, -3]
    end

    it "returns the subtraction with a 3-sized tuple" do
      (v1 - {1, 2, 3}).should eq Vector[2, 2, -3]
    end

    it "subtracts a size from a vector" do
      (V[1, 2, 3] - S[3, 2, 1]).should eq V[-2, 0, 2]
    end
  end

  describe "#*" do
    it "returns the multiplication with a number" do
      (v1 * 3).should eq Vector[9, 12, 0]
    end

    it "returns the element-wise multiplication between vectors" do
      (V[3, 9, 123] * V[1, 2, 3]).should eq V[3, 18, 369]
    end

    it "returns the element-wise multiplication with a 3-sized tuple" do
      (V[3, 9, 123] * {3, 2, 1}).should eq V[9, 18, 123]
    end
  end

  describe "#/" do
    it "returns the division by a number" do
      (v1 / 5).should eq Vector[0.6, 0.8, 0]
    end

    it "returns the element-wise division between vectors" do
      (V[3, 9, 128] / V[1, 2, 32]).should eq V[3, 4.5, 4]
    end

    it "returns the element-wise division with a 3-sized tuple" do
      (V[7, 3.2, 6] / {3.5, 1.6, 3}).should eq V[2, 2, 2]
    end
  end

  describe "#abs" do
    it "returns the element-wise absolute value of the vector" do
      V[-1, 5, 4].abs.should eq V[1, 5, 4]
    end
  end

  describe "#clamp" do
    it "clamps each element of a vector" do
      V[10, 5, -1].clamp(0..9).should eq V[9, 5, 0]
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

  describe "#image" do
    it "returns vector's pbc image" do
      vec = V[0.456, 0.1, 0.8]
      vec.image(1, 0, 0).should eq V[1.456, 0.1, 0.8]
      vec.image(-1, 0, 0).should eq V[-0.544, 0.1, 0.8]
      vec.image(-1, 1, -5).should eq V[-0.544, 1.1, -4.2]
    end
  end

  describe "#image" do
    it "returns vector's pbc image" do
      lat = Lattice.new S[8.77, 9.5, 24.74], 88.22, 80, 70.34
      vec = V[8.745528, 6.330571, 1.334073]
      vec.image(lat, 1, 0, 0).should be_close V[17.515528, 6.330571, 1.334073], 1e-6
      vec.image(lat, -1, 0, 0).should be_close V[-0.024472, 6.330571, 1.334073], 1e-6
      vec.image(lat, -1, 1, -5).should be_close V[-18.308592, 18.870709, -120.433621], 1e-6
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

  describe "#size" do
    it "returns the size of the vector" do
      Vector.origin.size.should eq 0
      v1.size.should eq 5
      v1.inv.size.should eq 5
      Vector[0.6, 0.8, 0].size.should eq 1
    end
  end

  describe "#normalize" do
    it "returns the unit vector" do
      v1.normalize.should be_close Vector[0.6, 0.8, 0], 1e-15
    end
  end

  describe "#pad" do
    it "pads a vector by the given amount" do
      V[1, 0, 0].pad(2).should eq V[3, 0, 0]
      V[0.34, 0.16, 0.1].pad(2.5).size.should eq 2.888844441904472
    end
  end

  describe "#resize" do
    it "resizes a vector to an arbitrary size" do
      V[1, 0, 0].resize(5).should eq V[5, 0, 0]
      (V[1, 1, 0] * 4.2).resize(1).should eq V[Math.sqrt(0.5), Math.sqrt(0.5), 0]
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

  describe "#to_cartesian" do
    it "converts fractional to Cartesian coordinates" do
      basis = Basis.new S[20, 20, 16]
      V[0.5, 0.65, 1].to_cartesian(basis).should be_close V[10, 13, 16], 1e-15
      V[1.5, 0.23, 0.9].to_cartesian(basis).should be_close V[30, 4.6, 14.4], 1e-15

      basis = Basis.new S[20, 10, 16]
      V[0.5, 0.65, 1].to_cartesian(basis).should be_close V[10, 6.5, 16], 1e-15

      basis = Basis.new(
        V[8.497, 0.007, 0.031],
        V[10.148, 42.359, 0.503],
        V[7.296, 2.286, 53.093])
      V[0.724, 0.04, 0.209].to_cartesian(basis).should be_close V[8.083, 2.177, 11.139], 1e-3
    end
  end

  describe "#to_fractional" do
    it "converts Cartesian to fractional coordinates" do
      basis = Basis.new S[10, 20, 30]
      V.zero.to_fractional(basis).should eq V.zero
      V[1, 2, 3].to_fractional(basis).should be_close V[0.1, 0.1, 0.1], 1e-15
      V[2, 3, 15].to_fractional(basis).should be_close V[0.2, 0.15, 0.5], 1e-15

      basis = Basis.new S[20, 20, 30]
      V[1, 2, 3].to_fractional(basis).should be_close V[0.05, 0.1, 0.1], 1e-15
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

  describe "#wrap" do
    it "wraps a fractional vector" do
      V[0, 0, 0].wrap.should eq V[0, 0, 0]
      V[1, 1, 1].wrap.should eq V[1, 1, 1]
      V[0.5, 0.3, 1].wrap.should eq V[0.5, 0.3, 1]
      V[0.5, 0.3, 1.1].wrap.should be_close V[0.5, 0.3, 0.1], 1e-15
      V[0.01, -0.3, 2.4].wrap.should be_close V[0.01, 0.7, 0.4], 1e-15
    end

    it "wraps a fractional vector around a center" do
      center = V.origin

      V[0, 0, 0].wrap(center).should eq V[0, 0, 0]
      V[1, 1, 1].wrap(center).should eq V[0, 0, 0]
      V[0.5, 0.3, 1].wrap(center).should eq V[0.5, 0.3, 0]
      V[0.5, 0.3, 1.1].wrap(center).should be_close V[0.5, 0.3, 0.1], 1e-15
      V[0.01, -0.3, 2.4].wrap(center).should be_close V[0.01, -0.3, 0.4], 1e-12
    end

    it "wraps a Cartesian vector" do
      lattice = Chem::Lattice.new S[15, 20, 9]

      V[0, 0, 0].wrap(lattice).should eq V[0, 0, 0]
      V[15, 20, 9].wrap(lattice).should be_close V[15, 20, 9], 1e-12
      V[10, 10, 5].wrap(lattice).should be_close V[10, 10, 5], 1e-12
      V[15.5, 21, -5].wrap(lattice).should be_close V[0.5, 1, 4], 1e-12
    end

    it "wraps a Cartesian vector around a center" do
      lattice = Chem::Lattice.new S[32, 20, 19]
      center = V[32, 20, 19]

      [
        {V[0, 0, 0], V[32, 20, 19]},
        {V[32, 20, 19], V[32, 20, 19]},
        {V[20.285, 14.688, 16.487], V[20.285, 14.688, 16.487]},
        {V[23.735, 19.25, 1.716], V[23.735, 19.25, 20.716]},
      ].each do |vec, expected|
        vec.wrap(lattice, center).should be_close expected, 1e-12
      end
    end
  end
end
