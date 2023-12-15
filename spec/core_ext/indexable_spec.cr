require "../spec_helper"

describe Indexable do
  describe "#[]" do
    it "returns a tuple of elements" do
      (0..9).map(&.**(2))[{2, 5, 9}].should eq({4, 25, 81})
      (0..9).map(&.**(2))[2, 5, 9].should eq({4, 25, 81})
    end

    it "returns an array of elements" do
      (0..9).map(&.**(2))[[2, 5, 9]].should eq([4, 25, 81])
    end

    it "raises if out of bounds" do
      expect_raises(IndexError) { (0..9).to_a[{2, 15, 9}] }
      expect_raises(IndexError) { (0..19).to_a[[21, 15, 9]] }
    end
  end

  describe "#sentence" do
    it "joins elements as a sentence" do
      ([] of String).sentence.should eq ""
      %w(one).sentence.should eq "one"
      %w(one two).sentence.should eq "one and two"
      %w(one two three).sentence.should eq "one, two, and three"

      %w(one two).sentence(pair_separator: "-").should eq "one-two"
      %w(one two three).sentence("-", tail_separator: "--").should eq "one-two--three"
    end

    it "joins elements as a sentence with block" do
      %w(one two three).sentence(&.upcase).should eq "ONE, TWO, and THREE"
    end
  end
end
