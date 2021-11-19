require "../spec_helper"

describe Chem::Spatial::Size3 do
  describe ".[]" do
    it "returns a size" do
      Chem::Spatial::Size3[1, 2, 3].should eq Chem::Spatial::Size3.new(1, 2, 3)
    end
  end

  describe ".zero" do
    it "returns a zero size" do
      Chem::Spatial::Size3.zero.should eq Chem::Spatial::Size3.new(0, 0, 0)
    end
  end

  describe "#*" do
    it "returns the size multiplied by a number" do
      (Chem::Spatial::Size3[1, 2, 3] * 3).should eq Chem::Spatial::Size3[3, 6, 9]
    end
  end

  describe "#/" do
    it "returns the size divided by a number" do
      (Chem::Spatial::Size3[1, 2, 3] / 0.5).should eq Chem::Spatial::Size3[2, 4, 6]
    end
  end

  describe "#[]" do
    it "returns the element at index" do
      size = Chem::Spatial::Size3[10, 20, 30]
      size[0].should eq 10
      size[1].should eq 20
      size[2].should eq 30
    end

    it "raises if index is out of bounds" do
      expect_raises IndexError do
        Chem::Spatial::Size3[10, 20, 30][4]
      end
    end

    it "raises if index is negative" do
      expect_raises IndexError do
        Chem::Spatial::Size3[10, 20, 30][-1]
      end
    end
  end
end
