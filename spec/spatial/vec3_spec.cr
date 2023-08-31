require "../spec_helper"

describe Chem::Spatial::Vec3 do
  v1 = vec3(3.0, 4.0, 0.0)
  v2 = vec3(1.0, 2.0, 3.0)

  describe ".[]" do
    it "returns a vector with the given components" do
      Chem::Spatial::Vec3[1, 2, 3].should eq [1, 2, 3]
    end

    it "returns a vector given a direction" do
      Chem::Spatial::Vec3[:z].should eq vec3(0, 0, 1)
      Chem::Spatial::Vec3[:yz].should eq vec3(0, 1, 1).normalize
      Chem::Spatial::Vec3[:xyz].should eq vec3(1, 1, 1).normalize
    end
  end

  describe ".new" do
    it "returns a vector given a direction" do
      Chem::Spatial::Vec3.new(:y).should eq vec3(0, 1, 0)
      Chem::Spatial::Vec3.new(:xy).should eq vec3(1, 1, 0).normalize
      Chem::Spatial::Vec3.new(:xyz).should eq vec3(1, 1, 1).normalize
    end
  end

  describe ".rand" do
    it "returns a random vector" do
      vec = Chem::Spatial::Vec3.rand
      (0..2).all? { |i| 0 <= vec[i] <= 1 }.should be_true
    end
  end

  describe ".zero" do
    it "returns a vector zero" do
      vec3(0, 0, 0).should eq [0, 0, 0]
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
      v1.should eq [3.0, 4.0, 0.0]
    end
  end

  describe "#+" do
    it "returns the element-wise arithmetic addition with a number" do
      (vec3(1, 2, 3) + 5).should eq [6, 7, 8]
    end

    it "returns the arithmetic addition between vectors" do
      (v1 + v2).should eq [4, 6, 3]
    end

    it "sums a vector and a size" do
      (vec3(1, 2, 3) + size3(3, 2, 1)).should eq [4, 4, 4]
    end
  end

  describe "#-" do
    it "returns the inverse vector" do
      (-v1).should eq [-3, -4, 0]
    end

    it "returns the element-wise subtraction with a number" do
      (vec3(3, 9, 123) - 5).should eq [-2, 4, 118]
    end

    it "returns the subtraction between vectors" do
      (v1 - v2).should eq [2, 2, -3]
    end

    it "subtracts a size from a vector" do
      (vec3(1, 2, 3) - size3(3, 2, 1)).should eq [-2, 0, 2]
    end
  end

  describe "#*" do
    it "returns the multiplication with a number" do
      (v1 * 3).should eq [9, 12, 0]
    end

    it "returns the element-wise multiplication between vectors" do
      (vec3(3, 9, 123) * vec3(1, 2, 3)).should eq [3, 18, 369]
    end
  end

  describe "#/" do
    it "returns the division by a number" do
      (v1 / 5).should eq [0.6, 0.8, 0]
    end

    it "returns the element-wise division between vectors" do
      (vec3(3, 9, 128) / vec3(1, 2, 32)).should eq [3, 4.5, 4]
    end
  end

  describe "#abs" do
    it "returns the length of the vector" do
      vec3(0, 0, 0).abs.should eq 0
      v1.abs.should eq 5
      v1.inv.abs.should eq 5
      vec3(0.6, 0.8, 0).abs.should eq 1
    end
  end

  describe "#cross" do
    it "returns the cross product between two vectors" do
      vec3(1, 0, 0).cross(vec3(0, 1, 0)).should eq [0, 0, 1]
      vec3(2, 3, 4).cross(vec3(5, 6, 7)).should eq [-3, 6, -3]
    end
  end

  describe "#close_to?" do
    it "returns true if vectors are within delta" do
      vec3(1, 2, 3).close_to?(vec3(1, 2, 3)).should be_true
      vec3(1, 2, 3).close_to?(vec3(1.001, 1.999, 3.00004), 1e-3).should be_true
    end

    it "returns false if vectors aren't within delta" do
      vec3(1, 2, 3).close_to?(vec3(3, 2, 1)).should be_false
      vec3(1, 2, 3).close_to?(vec3(1.001, 1.999, 3.00004), 1e-8).should be_false
    end
  end

  describe "#dot" do
    it "returns the dot product between two vectors" do
      vec3(3, 4, 0).dot(vec3(4, 4, 2)).should eq 28
    end
  end

  describe "#image" do
    it "returns vector's pbc image" do
      vec = vec3(0.456, 0.1, 0.8)
      vec.image(1, 0, 0).should eq [1.456, 0.1, 0.8]
      vec.image(-1, 0, 0).should eq [-0.544, 0.1, 0.8]
      vec.image(-1, 1, -5).should eq [-0.544, 1.1, -4.2]
    end
  end

  describe "#inv" do
    it "returns the inverse vector" do
      v1.inv.should eq [-3, -4, 0]
    end
  end

  describe "#map" do
    it "returns the element-wise map operation of the vector" do
      vec3(-5, 1, 0).map(&.**(2)).should eq [25, 1, 0]
    end
  end

  describe "#map_with_index" do
    it "returns the element-wise map operation of the vector" do
      vec3(2, 75, 2).map_with_index { |value, i| value + i**2 }.should eq [2, 76, 6]
    end
  end

  describe "#normalize" do
    it "returns the unit vector" do
      v1.normalize.should be_close [0.6, 0.8, 0], 1e-15
    end
  end

  describe "#pad" do
    it "pads a vector by the given amount" do
      vec3(1, 0, 0).pad(2).should eq [3, 0, 0]
      vec3(0.34, 0.16, 0.1).pad(2.5).abs.should eq 2.888844441904472
    end
  end

  describe "#project" do
    it "returns the projection on the vector" do
      vec3(1, 2, 3).project(vec3(1, 0, 1)).should be_close [2, 0, 2], 1e-15
    end

    it "returns the projection onto the direction" do
      vec3(1, 2, 3).project(:y).should be_close vec3(0, 2, 0), 1e-15
      vec3(1, 2, 3).project(:xz).should be_close vec3(2, 0, 2), 1e-15
    end
  end

  describe "#reject" do
    it "returns the rejection on the vector" do
      vec3(5, 5, 0).reject(vec3(0, 10, 0)).should be_close [5, 0, 0], 1e-15
      vec3(1, 2, 3).reject(vec3(1, 0, 1)).should be_close [-1, 2, 1], 1e-15
    end

    it "returns the projection onto the direction" do
      vec3(1, 2, 3).reject(:y).should be_close vec3(1, 0, 3), 1e-15
      vec3(1, 2, 3).reject(:xz).should be_close vec3(-1, 2, 1), 1e-15
    end
  end

  describe "#resize" do
    it "resizes a vector to an arbitrary size" do
      vec3(1, 0, 0).resize(5).should eq [5, 0, 0]
      (vec3(1, 1, 0) * 4.2).resize(1).should eq [Math.sqrt(0.5), Math.sqrt(0.5), 0]
    end
  end

  describe "#rotate" do
    it "rotates a vector" do
      vec3(1, 0, 0).rotate(about: vec3(0, 0, 1), by: 90).should be_close [0, 1, 0], 1e-15
      vec3(1, 2, 0).rotate(about: vec3(0, 0, -1), by: 60).should be_close [2.23, 0.13, 0], 1e-2
      vec3(0, 1, 0).rotate(about: vec3(1, 1, 1), by: 120).should be_close [0, 0, 1], 1e-15
    end

    it "rotates about a direction" do
      vec3(1, 0, 0).rotate(about: :z, by: 90).should be_close [0, 1, 0], 1e-15
      vec3(0, 1, 0).rotate(about: :xyz, by: 120).should be_close [0, 0, 1], 1e-15
    end
  end

  describe "#to_a" do
    it "returns an array" do
      v1.to_a.should eq [3, 4, 0]
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expected = "Vec3[ 1.253224 -23125  2.13e-05 ]"
      vec3(1.25322376, -23125, 0.00002130000).to_s.should eq expected
    end
  end

  describe "#transform" do
    it "returns a transformed vector" do
      vec3(3, 2, 1).transform { |x, y, z| {x * 2, y, z / 0.5} }.should eq [6, 2, 2]
    end
  end

  describe "#zero?" do
    it "returns whether the vector is zero" do
      vec3(0, 0, 0).zero?.should be_true
      v1.zero?.should be_false
      v1.inv.zero?.should be_false
    end
  end

  describe "#wrap" do
    it "wraps a fractional vector" do
      vec3(0, 0, 0).wrap.should eq [0, 0, 0]
      vec3(1, 1, 1).wrap.should eq [1, 1, 1]
      vec3(0.5, 0.3, 1).wrap.should eq [0.5, 0.3, 1]
      vec3(0.5, 0.3, 1.1).wrap.should be_close [0.5, 0.3, 0.1], 1e-15
      vec3(0.01, -0.3, 2.4).wrap.should be_close [0.01, 0.7, 0.4], 1e-15
    end

    it "wraps a fractional vector around a center" do
      center = vec3(0, 0, 0)

      vec3(0, 0, 0).wrap(center).should eq [0, 0, 0]
      vec3(1, 1, 1).wrap(center).should eq [0, 0, 0]
      vec3(0.5, 0.3, 1).wrap(center).should eq [0.5, 0.3, 0]
      vec3(0.5, 0.3, 1.1).wrap(center).should be_close [0.5, 0.3, 0.1], 1e-15
      vec3(0.01, -0.3, 2.4).wrap(center).should be_close [0.01, -0.3, 0.4], 1e-12
    end
  end

  describe "#x?" do
    it "tells if the vector lies along the X axis" do
      vec3(0, 0, 0).x?.should be_false
      vec3(0, 0, 1).x?.should be_false
      vec3(0, 1, 0).x?.should be_false
      vec3(0, 1, 1).x?.should be_false
      vec3(1, 0, 0).x?.should be_true
      vec3(1, 0, 1).x?.should be_false
      vec3(1, 1, 0).x?.should be_false
      vec3(1, 1, 1).x?.should be_false
    end
  end

  describe "#xy?" do
    it "tells if the vector lies in the XY plane" do
      vec3(0, 0, 0).xy?.should be_false
      vec3(0, 0, 1).xy?.should be_false
      vec3(0, 1, 0).xy?.should be_true
      vec3(0, 1, 1).xy?.should be_false
      vec3(1, 0, 0).xy?.should be_true
      vec3(1, 0, 1).xy?.should be_false
      vec3(1, 1, 0).xy?.should be_true
      vec3(1, 1, 1).xy?.should be_false
    end
  end

  describe "#xz?" do
    it "tells if the vector lies in the XZ plane" do
      vec3(0, 0, 0).xz?.should be_false
      vec3(0, 0, 1).xz?.should be_true
      vec3(0, 1, 0).xz?.should be_false
      vec3(0, 1, 1).xz?.should be_false
      vec3(1, 0, 0).xz?.should be_true
      vec3(1, 0, 1).xz?.should be_true
      vec3(1, 1, 0).xz?.should be_false
      vec3(1, 1, 1).xz?.should be_false
    end
  end

  describe "#y?" do
    it "tells if the vector lies along the Y axis" do
      vec3(0, 0, 0).y?.should be_false
      vec3(0, 0, 1).y?.should be_false
      vec3(0, 1, 0).y?.should be_true
      vec3(0, 1, 1).y?.should be_false
      vec3(1, 0, 0).y?.should be_false
      vec3(1, 0, 1).y?.should be_false
      vec3(1, 1, 0).y?.should be_false
      vec3(1, 1, 1).y?.should be_false
    end
  end

  describe "#yz?" do
    it "tells if the vector lies in the YZ plane" do
      vec3(0, 0, 0).yz?.should be_false
      vec3(0, 0, 1).yz?.should be_true
      vec3(0, 1, 0).yz?.should be_true
      vec3(0, 1, 1).yz?.should be_true
      vec3(1, 0, 0).yz?.should be_false
      vec3(1, 0, 1).yz?.should be_false
      vec3(1, 1, 0).yz?.should be_false
      vec3(1, 1, 1).yz?.should be_false
    end
  end

  describe "#z?" do
    it "tells if the vector lies along the Z axis" do
      vec3(0, 0, 0).z?.should be_false
      vec3(0, 0, 1).z?.should be_true
      vec3(0, 1, 0).z?.should be_false
      vec3(0, 1, 1).z?.should be_false
      vec3(1, 0, 0).z?.should be_false
      vec3(1, 0, 1).z?.should be_false
      vec3(1, 1, 0).z?.should be_false
      vec3(1, 1, 1).z?.should be_false
    end
  end

  describe "#to_io" do
    it "writes a binary representation of the vector" do
      vec = vec3(1.1, 2.2, 3.3)
      io = IO::Memory.new
      io.write_bytes vec
      io.rewind
      Array.new(3) { io.read_bytes Float64 }.should eq vec.to_a
      io.read_byte.should be_nil
    end
  end

  describe ".from_io" do
    it "reads a vector from IO" do
      vec = vec3(1.1, 2.2, 3.3)
      io = IO::Memory.new
      io.write_bytes vec
      io.rewind
      io.read_bytes(Chem::Spatial::Vec3).should eq vec
    end
  end
end
