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

  describe "#[]" do
    it "raises if index is out of bounds" do
      expect_raises IndexError do
        S[10, 20, 30][4]
      end
    end
  end

  describe "#[]?" do
    it "returns the element at index" do
      size = S[10, 20, 30]
      size[0]?.should eq 10
      size[1]?.should eq 20
      size[2]?.should eq 30
    end

    it "returns nil if index is out of bounds" do
      S[10, 20, 30][4]?.should be_nil
    end

    it "returns nil if index is negative" do
      S[10, 20, 30][-1]?.should be_nil
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the bounds" do
      S[6, 4, 23].volume.should eq 552
    end
  end
end
