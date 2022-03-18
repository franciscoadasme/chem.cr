require "../spec_helper"

describe Enumerable do
  describe "#average" do
    it "returns the weighted average" do
      (1..9).average((0..8).to_a).should eq 20 / 3
      (1..9).to_a.average((0..8).to_a).should eq 20 / 3
    end

    it "returns the weighted average with block" do
      (1..9).average((0..8).to_a, &.**(2)).should eq 145 / 3
      (1..9).to_a.average((0..8).to_a, &.**(2)).should eq 145 / 3
      ["Alice", "Bob"].average([7, 2], &.size).should eq 4.555555555555555
      ('a'..'z').average((0..25).to_a, &.ord).should eq 114
    end

    it "raises if incompatible sizes" do
      expect_raises(ArgumentError) { (1..5).average([0, 1]) }
      expect_raises(ArgumentError) { [1, 2, 3, 4].average([0, 1, 2]) }
    end

    it "raises if empty" do
      expect_raises(Enumerable::EmptyError) { ([] of Int32).average([1, 1, 1]) }
    end
  end

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
