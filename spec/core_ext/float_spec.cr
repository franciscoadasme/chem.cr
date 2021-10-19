require "../spec_helper"

describe Float do
  describe "#close_to?" do
    it "returns true if numbers are within delta" do
      1.0.close_to?(1.0).should be_true
      1.0_f32.close_to?(1.0).should be_true
      1.0.close_to?(1.0 + Float64::EPSILON).should be_true
      1.0_f32.close_to?(1.0 + Float32::EPSILON).should be_true
      1.0.close_to?(1.0005, 1e-3).should be_true
    end

    it "returns false if numbers aren't within delta" do
      1.0.close_to?(1.0 + Float64::EPSILON*2).should be_false
      1.0_f32.close_to?(1.0 + Float32::EPSILON*2).should be_false
      1.0.close_to?(1.01, 1e-3).should be_false
    end
  end
end
