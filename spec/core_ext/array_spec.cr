require "../spec_helper"

describe Array do
  describe "#sort!" do
    it "doesn't change the array with a negative- or zero-sized range" do
      ary = [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
      ary.sort! 5..2
      ary.should eq [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
    end

    it "sorts in-place the values within the given range" do
      ary = [14, 94, 70, 52, 54, 66, 95, 58, 55, 95]
      ary.sort! 0..4
      ary.should eq [14, 52, 54, 70, 94, 66, 95, 58, 55, 95]
    end

    it "sorts in-place the values within the given range (negative index)" do
      ary = [14, 94, 70, 52, 54, 66, 95, 58, 55, 95]
      ary.sort! 2..-4
      ary.should eq [14, 94, 52, 54, 66, 70, 95, 58, 55, 95]
    end

    it "sorts in-place the values within the given range with block" do
      ary = [94, 70, 52, 54, 66, 95, 58, 55, 95, 88, 98, 4, 45, 95]
      ary.sort! 6..-2 { |a, b| b <=> a }
      ary.should eq [94, 70, 52, 54, 66, 95, 98, 95, 88, 58, 55, 45, 4, 95]
    end

    it "fails with invalid range" do
      expect_raises IndexError do
        [94, 70, 52, 54, 66].sort! 6..-1
      end
    end
  end
end
