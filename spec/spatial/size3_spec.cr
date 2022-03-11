require "../spec_helper"

describe Chem::Spatial::Size3 do
  describe ".[]" do
    it "returns a size" do
      size = Chem::Spatial::Size3[1, 2, 3]
      size.should be_a Chem::Spatial::Size3
      size.should eq [1, 2, 3]
    end
  end

  describe ".zero" do
    it "returns a zero size" do
      Chem::Spatial::Size3.zero.should eq [0, 0, 0]
    end
  end

  describe "#+" do
    it "sums two sizes" do
      size1 = size3(1, 2, 3)
      size2 = size3(2.35, 1.28, 123.3)
      (size1 + size2).should be_close [3.35, 3.28, 126.3], 1e-3
    end
  end

  describe "#-" do
    it "subtracts two sizes" do
      size1 = size3(1, 2, 3)
      size2 = size3(2.35, 5.28, 123.3)
      (size2 - size1).should be_close [1.35, 3.28, 120.3], 1e-3
    end

    it "clamps to zero if negative" do
      (size3(1, 7.28, 3) - size3(2.35, 5.28, 123.3)).should be_close [0, 2, 0], 1e-3
    end
  end

  describe "#*" do
    it "returns the size multiplied by a number" do
      (size3(1, 2, 3) * 3).should eq [3, 6, 9]
    end

    it "returns the multiplication of two sizes" do
      (size3(1, 2, 4) * size3(0.5, 9, 1.2)).should eq [0.5, 18, 4.8]
    end
  end

  describe "#/" do
    it "returns the size divided by a number" do
      (size3(1, 2, 3) / 0.5).should eq [2, 4, 6]
    end

    it "returns the division of two sizes" do
      (size3(1, 2, 3) / size3(0.5, 8, 1.5)).should eq [2, 0.25, 2]
    end
  end

  describe "#[]" do
    it "returns the element at index" do
      size = size3(10, 20, 30)
      size[0].should eq 10
      size[1].should eq 20
      size[2].should eq 30
    end

    it "raises if index is out of bounds" do
      expect_raises IndexError do
        size3(10, 20, 30)[4]
      end
    end

    it "raises if index is negative" do
      expect_raises IndexError do
        size3(10, 20, 30)[-1]
      end
    end
  end
end
