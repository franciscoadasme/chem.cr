require "../spec_helper"

describe Indexable do
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
