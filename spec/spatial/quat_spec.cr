require "../spec_helper"

describe Chem::Spatial::Quat do
  describe ".[]" do
    it "returns a quaternion with each of the given components" do
      Chem::Spatial::Quat[1, 2, 3, 4].should eq Chem::Spatial::Quat.new(1, 2, 3, 4)
    end
  end

  describe ".aligning" do
    it "returns a quaternion encoding the rotation to align v1 to v2" do
      Chem::Spatial::Quat.aligning(vec3(1, 0, 0), vec3(0, 1, 0)).should be_close Chem::Spatial::Quat[0.71, 0.0, 0.0, 0.71], 1e-2
    end

    it "returns a quaternion to align two pairs of vectors" do
      q = Chem::Spatial::Quat.rotation(vec3(1, 2, 3), 65)
      i = vec3(1, 0, 0)
      j = vec3(0, 1, 0.5)
      k = vec3(0.1, 0.2, 1)
      ii = q * i
      jj = q * j
      kk = q * k
      q = Chem::Spatial::Quat.aligning({ii, jj}, to: {i, j})
      (q * ii).should be_close i, 1e-15
      (q * jj).should be_close j, 1e-15
      (q * kk).should be_close k, 1e-15
    end
  end

  describe ".rotation" do
    it "returns a quaternion encoding the given rotation" do
      Chem::Spatial::Quat.rotation(vec3(1, 0, 0), 90).should be_close Chem::Spatial::Quat[0.71, 0.71, 0, 0], 1e-2
      Chem::Spatial::Quat.rotation(vec3(0.71, 0.71, 0), 60).should be_close Chem::Spatial::Quat[0.87, 0.35, 0.35, 0], 1e-2
      Chem::Spatial::Quat.rotation(vec3(0.67, 0.68, 0.3), 180).should be_close Chem::Spatial::Quat[0, 0.67, 0.68, 0.3], 1e-2
      Chem::Spatial::Quat.rotation(vec3(0.67, 0.68, 0.3), 360).should be_close Chem::Spatial::Quat[-1, 0, 0, 0], 1e-2
      Chem::Spatial::Quat.rotation(vec3(0.67, 0.68, 0.3), -180).should be_close Chem::Spatial::Quat[0, -0.67, -0.68, -0.3], 1e-2
      Chem::Spatial::Quat.rotation(vec3(0.31, 0.91, -0.28), 46).should be_close Chem::Spatial::Quat[0.92, 0.12, 0.36, -0.11], 1e-2
      Chem::Spatial::Quat.rotation(vec3(1, 1, 1), 120).should be_close Chem::Spatial::Quat[0.5, 0.5, 0.5, 0.5], 1e-15
    end

    it "returns the rotation by Euler angles" do
      Chem::Spatial::Quat.rotation(65, 0, 0).should be_close Chem::Spatial::Quat[0.843, 0.537, 0, 0], 1e-3
      Chem::Spatial::Quat.rotation(0, 76, 0).should be_close Chem::Spatial::Quat[0.788, 0, 0.616, 0], 1e-3
      Chem::Spatial::Quat.rotation(0, 0, 81).should be_close Chem::Spatial::Quat[0.760, 0, 0, 0.649], 1e-3
      Chem::Spatial::Quat.rotation(-157, 17, -83).should be_close Chem::Spatial::Quat[0.052, -0.745, -0.62, -0.239], 1e-3
    end
  end

  describe "#+" do
    it "sums two quaternions" do
      (Chem::Spatial::Quat[1, 2, 3, 4] + Chem::Spatial::Quat[4, 3, 2, 1]).should eq Chem::Spatial::Quat[5, 5, 5, 5]
    end
  end

  describe "#-" do
    it "negates a quaternion" do
      (-Chem::Spatial::Quat[1, 2, 3, 4]).should eq Chem::Spatial::Quat[-1, -2, -3, -4]
    end

    it "subtracts two quaternions" do
      (Chem::Spatial::Quat[1, 2, 3, 4] - Chem::Spatial::Quat[4, 3, 2, 1]).should eq Chem::Spatial::Quat[-3, -1, 1, 3]
    end
  end

  describe "#*" do
    it "multiplies two quaternions" do
      (Chem::Spatial::Quat[1, 2, 3, 4] * Chem::Spatial::Quat[4, 3, 2, 1]).should eq Chem::Spatial::Quat[-12, 6, 24, 12]
      (Chem::Spatial::Quat[1, 2, 3, 4] * Chem::Spatial::Quat[1, 4, 5, 6]).should eq Chem::Spatial::Quat[-46, 4, 12, 8]
    end

    it "multiplies a quaternion with a number" do
      (Chem::Spatial::Quat[1, 2, 3, 4] * 2).should eq Chem::Spatial::Quat[2, 4, 6, 8]
    end

    it "multiplies a quaternion with a vector" do
      q = Chem::Spatial::Quat.aligning vec3(1, 0, 0), to: vec3(1, 2, 3)
      (q * vec3(1, 0, 0)).should be_close vec3(1, 2, 3).normalize, 1e-15
      (Chem::Spatial::Quat.rotation(vec3(0, 0, 1), 90) * vec3(1, 0, 0)).should be_close [0, 1, 0], 1e-15
      (Chem::Spatial::Quat.rotation(vec3(0, 0, 1), 180) * vec3(1, 1, 0)).should be_close [-1, -1, 0], 1e-15
      (Chem::Spatial::Quat.rotation(vec3(0, 0, -1), 60) * vec3(1, 2, 0)).should be_close [2.23, 0.13, 0], 1e-2
      (Chem::Spatial::Quat.rotation(vec3(0, 1, 0), 90) * vec3(0, 0, 4)).should be_close [4, 0, 0], 1e-15
      (Chem::Spatial::Quat.rotation(vec3(1, 1, 1), 120) * vec3(0, 1, 0)).should be_close [0, 0, 1], 1e-15
    end
  end

  describe "#abs" do
    it "returns the quaternion's norm" do
      Chem::Spatial::Quat[1, 2, 3, 4].abs.should eq Math.sqrt(30)
    end
  end

  describe "#abs2" do
    it "returns the square quaternion's norm" do
      Chem::Spatial::Quat[1, 2, 3, 4].abs2.should eq Math.sqrt(900)
    end
  end

  describe "#close_to?" do
    it "returns true if quaternions are within delta" do
      Chem::Spatial::Quat[1, 2, 3, 4].close_to?(Chem::Spatial::Quat[1, 2, 3, 4]).should be_true
      Chem::Spatial::Quat[1, 2, 3, 4].close_to?(Chem::Spatial::Quat[1.001, 1.999, 3.00004, 4], 1e-3).should be_true
    end

    it "returns false if quaternions aren't within delta" do
      Chem::Spatial::Quat[1, 2, 3, 4].close_to?(Chem::Spatial::Quat[4, 3, 2, 1]).should be_false
      Chem::Spatial::Quat[1, 2, 3, 4].close_to?(Chem::Spatial::Quat[1.001, 1.999, 3.00004, 4], 1e-8).should be_false
    end
  end

  describe "#conj" do
    it "returns the conjugate of a quaternion" do
      Chem::Spatial::Quat[1, 2, 3, 4].conj.should eq Chem::Spatial::Quat[1, -2, -3, -4]
      Chem::Spatial::Quat[1, 2, 3, 4].conj.conj.should eq Chem::Spatial::Quat[1, 2, 3, 4]
    end
  end

  describe "#dot" do
    it "returns the inner product between two quaternions" do
      Chem::Spatial::Quat[1, 2, 3, 4].dot(Chem::Spatial::Quat[1, 2, 3, 4]).should eq 30
    end
  end

  describe "#imag" do
    it "returns the imaginary (vector) part of the quaternion" do
      Chem::Spatial::Quat[1, 0, 0, 0].imag.should eq [0, 0, 0]
      Chem::Spatial::Quat[1, 2, 3, 4].imag.should eq [2, 3, 4]
    end
  end

  describe "#inv" do
    it "returns the inverse of a quaternion" do
      Chem::Spatial::Quat[1, 0, 0, 0].inv.should eq Chem::Spatial::Quat[1, 0, 0, 0]
      Chem::Spatial::Quat[0.5, 0.5, 0.5, 0.5].inv.should eq Chem::Spatial::Quat[0.5, -0.5, -0.5, -0.5]
      Chem::Spatial::Quat[0.3, 0.15, -2.5, 0.153].inv.should be_close Chem::Spatial::Quat[0.05, -0.02, 0.39, -0.02], 1e-2

      q = Chem::Spatial::Quat[5.2, 1.2, 6.4, 5.24]
      (q * q.inv).should be_close Chem::Spatial::Quat[1, 0, 0, 0], 1e-15
    end
  end

  describe "#normalize" do
    it "returns a normalized quaternion" do
      Chem::Spatial::Quat[1, 0, 0, 0].normalize.should eq Chem::Spatial::Quat[1, 0, 0, 0]
      Chem::Spatial::Quat[0, 0.71, 0.71, 0].normalize.should be_close Chem::Spatial::Quat[0, 0.71, 0.71, 0], 1e-2
      Chem::Spatial::Quat[1, 2, 3, 4].normalize.abs.should be_close 1, 1e-15
    end
  end

  describe "#real" do
    it "returns the real (scalar) part of the quaternion" do
      Chem::Spatial::Quat[1, 0, 0, 0].real.should eq 1
      Chem::Spatial::Quat[4, 3, 2, 1].real.should eq 4
    end
  end

  describe "#to_mat3" do
    it "returns the 3x3 matrix" do
      q = Chem::Spatial::Quat.rotation(-157, 17, -83)
      vec = vec3(1, 2, 3)
      (q.to_mat3 * vec).should be_close (q * vec), 1e-14
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expected = "Quat[ 1.253223 -2  1235  2.13e-06 ]"
      Chem::Spatial::Quat[1.25322346, -2, 1235, 0.000002130000].to_s.should eq expected
    end
  end

  describe "#unit?" do
    it "returns true for a unit quaternion" do
      Chem::Spatial::Quat[0, 1, 1, 0].normalize.unit?.should be_true
    end

    it "returns false when a quaternion is not normalized" do
      Chem::Spatial::Quat[1, 2, 3, 4].unit?.should be_false
    end
  end

  describe "#zero?" do
    it "returns true for a zero quaternion" do
      Chem::Spatial::Quat[0, 0, 0, 0].zero?.should be_true
    end

    it "returns false when a quaternion is not zero" do
      Chem::Spatial::Quat[1, 2, 3, 4].zero?.should be_false
    end
  end
end
