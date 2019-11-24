require "../spec_helper"

describe Chem::Spatial::Size do
  describe ".[]" do
    it "returns a size" do
      S[1, 2, 3].should eq S.new(1, 2, 3)
    end
  end

  describe ".zero" do
    it "returns a zero size" do
      S.zero.should eq S.new(0, 0, 0)
    end
  end

  describe "#*" do
    it "returns the size multiplied by a number" do
      (S[1, 2, 3] * 3).should eq S[3, 6, 9]
    end
  end

  describe "#/" do
    it "returns the size divided by a number" do
      (S[1, 2, 3] / 0.5).should eq S[2, 4, 6]
    end
  end
end
