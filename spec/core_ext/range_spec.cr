require "../spec_helper"

describe Range do
  describe "#clamp" do
    it "clamps a range" do
      (1..40).clamp(0, 10).should eq 1..10
      (1..40).clamp(3, 10).should eq 3..10
      (1..).clamp(3, 10).should eq 3..10
      (..50).clamp(3, 10).should eq 3..10
      (..).clamp(3, 10).should eq 3..10

      (1..40).clamp(0..10).should eq 1..10
      (1..40).clamp(3..10).should eq 3..10
      (1..).clamp(3..10).should eq 3..10
      (..50).clamp(3..10).should eq 3..10
      (..).clamp(3..10).should eq 3..10
    end

    it "fails with an exclusive range" do
      expect_raises(ArgumentError) { (1...40).clamp(0, 10) }
    end

    it "fails when clamping by an exclusive range" do
      expect_raises(ArgumentError) { (1..40).clamp(0...10) }
    end
  end
end
