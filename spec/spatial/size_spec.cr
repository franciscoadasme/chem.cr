require "../spec_helper"

describe Chem::Spatial::Size do
  describe ".[]" do
    it "returns a size" do
      Size[1, 2, 3].should eq Size.new(1, 2, 3)
    end
  end

  describe ".zero" do
    it "returns a zero size" do
      Size.zero.should eq Size.new(0, 0, 0)
    end
  end

  describe "#*" do
    it "returns the size multiplied by a number" do
      (Size[1, 2, 3] * 3).should eq Size[3, 6, 9]
    end
  end

  describe "#/" do
    it "returns the size divided by a number" do
      (Size[1, 2, 3] / 0.5).should eq Size[2, 4, 6]
    end
  end

  describe "#[]" do
    it "raises if index is out of bounds" do
      expect_raises IndexError do
        Size[10, 20, 30][4]
      end
    end
  end

  describe "#[]?" do
    it "returns the element at index" do
      size = Size[10, 20, 30]
      size[0]?.should eq 10
      size[1]?.should eq 20
      size[2]?.should eq 30
    end

    it "returns nil if index is out of bounds" do
      Size[10, 20, 30][4]?.should be_nil
    end

    it "returns nil if index is negative" do
      Size[10, 20, 30][-1]?.should be_nil
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the bounds" do
      Size[6, 4, 23].volume.should eq 552
    end
  end
end
