require "../spec_helper"

describe Slice do
  describe "#concat" do
    it "concatenates two slices" do
      slice = Slice[1, 2, 3, 4]
      slice.concat(Slice[5, 6, 7, 8]).to_a.should eq (1..8).to_a
    end

    it "appends N elements from another slice" do
      slice = Slice[1, 2, 3, 4]
      slice.concat(Slice[5, 6, 7, 8], 2).to_a.should eq (1..6).to_a
    end

    it "appends N elements from a pointer" do
      slice = Slice[1, 2, 3, 4]
      ptr = Pointer.malloc(8) { |i| i + 10 }
      slice.concat(ptr, 3).to_a.should eq [1, 2, 3, 4, 10, 11, 12]
    end
  end

  describe "#skip" do
    it "returns a shifted slice" do
      slice = "abc def".to_slice
      slice.skip(&.chr.letter?).should eq slice[3, 4]
    end

    it "returns itself" do
      slice = "abcdef".to_slice
      slice.skip(&.chr.number?).should eq slice
    end

    it "returns an empty slice" do
      slice = "abcDEF".to_slice
      slice.skip(&.chr.letter?).should eq Bytes.empty
    end
  end

  describe "#take_while" do
    it "returns a slice with elements" do
      slice = "abc def".to_slice
      slice.take_while(&.chr.letter?).should eq slice[0, 3]
    end

    it "returns itself" do
      slice = "abcdef".to_slice
      slice.take_while(&.chr.letter?).should eq slice
    end

    it "returns an empty slice" do
      slice = "abcDEF".to_slice
      slice.take_while(&.chr.uppercase?).should eq slice[0, 0]
    end
  end

  describe "#unsafe_index" do
    it "returns the index of the byte" do
      slice = "abcdef".to_slice
      slice.unsafe_index('d'.ord).should eq 3
    end

    it "returns the index of any of the bytes" do
      slice = "abcdef".to_slice
      slice.unsafe_index('x'.ord, 'y'.ord, 'b'.ord).should eq 1
    end

    it "returns nil byte is not found" do
      slice = "abcdef".to_slice
      slice.unsafe_index('x'.ord).should be_nil
    end
  end
end
