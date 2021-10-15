require "../spec_helper"

describe Chem::Spatial::Quat do
  describe ".[]" do
    it "returns a quaternion with each of the given components" do
      Q[1, 2, 3, 4].should eq Q.new(1, 2, 3, 4)
    end
  end

  describe ".aligning" do
    it "returns a quaternion encoding the rotation to align v1 to v2" do
      Q.aligning(V[1, 0, 0], V[0, 1, 0]).should be_close Q[0.71, 0.0, 0.0, 0.71], 1e-2
    end
  end

  describe ".rotation" do
    it "returns a quaternion encoding the given rotation" do
      Q.rotation(V[1, 0, 0], 90).should be_close Q[0.71, 0.71, 0, 0], 1e-2
      Q.rotation(V[0.71, 0.71, 0], 60).should be_close Q[0.87, 0.35, 0.35, 0], 1e-2
      Q.rotation(V[0.67, 0.68, 0.3], 180).should be_close Q[0, 0.67, 0.68, 0.3], 1e-2
      Q.rotation(V[0.67, 0.68, 0.3], 360).should be_close Q[-1, 0, 0, 0], 1e-2
      Q.rotation(V[0.67, 0.68, 0.3], -180).should be_close Q[0, -0.67, -0.68, -0.3], 1e-2
      Q.rotation(V[0.31, 0.91, -0.28], 46).should be_close Q[0.92, 0.12, 0.36, -0.11], 1e-2
      Q.rotation(V[1, 1, 1], 120).should be_close Q[0.5, 0.5, 0.5, 0.5], 1e-15
    end
  end

  describe "#+" do
    it "sums two quaternions" do
      (Q[1, 2, 3, 4] + Q[4, 3, 2, 1]).should eq Q[5, 5, 5, 5]
    end
  end

  describe "#-" do
    it "negates a quaternion" do
      (-Q[1, 2, 3, 4]).should eq Q[-1, -2, -3, -4]
    end

    it "subtracts two quaternions" do
      (Q[1, 2, 3, 4] - Q[4, 3, 2, 1]).should eq Q[-3, -1, 1, 3]
    end
  end

  describe "#*" do
    it "multiplies two quaternions" do
      (Q[1, 2, 3, 4] * Q[4, 3, 2, 1]).should eq Q[-12, 6, 24, 12]
      (Q[1, 2, 3, 4] * Q[1, 4, 5, 6]).should eq Q[-46, 4, 12, 8]
    end

    it "multiplies a quaternion with a number" do
      (Q[1, 2, 3, 4] * 2).should eq Q[2, 4, 6, 8]
    end

    it "multiplies a quaternion with a vector" do
      q = Q.aligning Vec3[1, 0, 0], to: Vec3[1, 2, 3]
      (q * Vec3[1, 0, 0]).should be_close Vec3[1, 2, 3].normalize, 1e-15
      (Q.rotation(V[0, 0, 1], 90) * V[1, 0, 0]).should be_close V[0, 1, 0], 1e-15
      (Q.rotation(V[0, 0, 1], 180) * V[1, 1, 0]).should be_close V[-1, -1, 0], 1e-15
      (Q.rotation(V[0, 0, -1], 60) * V[1, 2, 0]).should be_close V[2.23, 0.13, 0], 1e-2
      (Q.rotation(V[0, 1, 0], 90) * V[0, 0, 4]).should be_close V[4, 0, 0], 1e-15
      (Q.rotation(V[1, 1, 1], 120) * V[0, 1, 0]).should be_close V[0, 0, 1], 1e-15
    end
  end

  describe "#abs" do
    it "returns the quaternion's norm" do
      Q[1, 2, 3, 4].abs.should eq Math.sqrt(30)
    end
  end

  describe "#abs2" do
    it "returns the square quaternion's norm" do
      Q[1, 2, 3, 4].abs2.should eq Math.sqrt(900)
    end
  end

  describe "#conj" do
    it "returns the conjugate of a quaternion" do
      Q[1, 2, 3, 4].conj.should eq Q[1, -2, -3, -4]
      Q[1, 2, 3, 4].conj.conj.should eq Q[1, 2, 3, 4]
    end
  end

  describe "#dot" do
    it "returns the inner product between two quaternions" do
      Q[1, 2, 3, 4].dot(Q[1, 2, 3, 4]).should eq 30
    end
  end

  describe "#imag" do
    it "returns the imaginary (vector) part of the quaternion" do
      Q[1, 0, 0, 0].imag.should eq Vec3[0, 0, 0]
      Q[1, 2, 3, 4].imag.should eq Vec3[2, 3, 4]
    end
  end

  describe "#inv" do
    it "returns the inverse of a quaternion" do
      Q[1, 0, 0, 0].inv.should eq Q[1, 0, 0, 0]
      Q[0.5, 0.5, 0.5, 0.5].inv.should eq Q[0.5, -0.5, -0.5, -0.5]
      Q[0.3, 0.15, -2.5, 0.153].inv.should be_close Q[0.05, -0.02, 0.39, -0.02], 1e-2

      q = Q[5.2, 1.2, 6.4, 5.24]
      (q * q.inv).should be_close Q[1, 0, 0, 0], 1e-15
    end
  end

  describe "#normalize" do
    it "returns a normalized quaternion" do
      Q[1, 0, 0, 0].normalize.should eq Q[1, 0, 0, 0]
      Q[0, 0.71, 0.71, 0].normalize.should be_close Q[0, 0.71, 0.71, 0], 1e-2
      Q[1, 2, 3, 4].normalize.abs.should be_close 1, 1e-15
    end
  end

  describe "#real" do
    it "returns the real (scalar) part of the quaternion" do
      Q[1, 0, 0, 0].real.should eq 1
      Q[4, 3, 2, 1].real.should eq 4
    end
  end

  describe "#unit?" do
    it "returns true for a unit quaternion" do
      Q[0, 1, 1, 0].normalize.unit?.should be_true
    end

    it "returns false when a quaternion is not normalized" do
      Q[1, 2, 3, 4].unit?.should be_false
    end
  end

  describe "#zero?" do
    it "returns true for a zero quaternion" do
      Q[0, 0, 0, 0].zero?.should be_true
    end

    it "returns false when a quaternion is not zero" do
      Q[1, 2, 3, 4].zero?.should be_false
    end
  end
end
