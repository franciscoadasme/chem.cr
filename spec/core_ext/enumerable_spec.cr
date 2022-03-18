require "../spec_helper"

describe Enumerable do
  describe "#mean" do
    it "returns the mean" do
      (1..40).mean.should eq 20.5
    end

    it "returns the mean with block" do
      (1..22).mean(&.**(2)).should eq 172.5
      ["Alice", "Bob"].mean(&.size).should eq 4
      ('a'..'z').mean(&.ord).should eq 109.5
    end

    it "raises if empty" do
      expect_raises(Enumerable::EmptyError) { ([] of Int32).mean }
    end
  end
end
