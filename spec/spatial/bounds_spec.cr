require "../spec_helper"

describe Chem::Spatial::Bounds do
  describe ".[]" do
    it "returns a bounds with the given size placed at origin" do
      bounds = Bounds[1, 2, 3]
      bounds.origin.should eq V.origin
      bounds.size.should eq S[1, 2, 3]
      bounds.angles.should eq({90, 90, 90})
    end
  end

  describe ".zero" do
    it "returns a zero-sized bounds placed at origin" do
      bounds = Bounds.zero
      bounds.origin.should eq V.origin
      bounds.size.should eq S[0, 0, 0]
      bounds.angles.should eq({0, 0, 0})
    end
  end

  describe "#+" do
    it "translates a bounds by a vector" do
      (Bounds[1, 2, 3] + V[3, 2, 1]).should eq Bounds.new(V[3, 2, 1], S[1, 2, 3])

      bounds = Bounds.new V[6, 1, 0], S[6, 6.5, 7]
      (bounds + V[1.5, 7.3, 1]).should eq Bounds.new(V[7.5, 8.3, 1], S[6, 6.5, 7])
    end
  end

  describe "#-" do
    it "translates a bounds by a vector" do
      (Bounds[1, 2, 3] - V[3, 2, 1]).should eq Bounds.new(V[-3, -2, -1], S[1, 2, 3])

      bounds = Bounds.new V[6, 1, 0], S[6, 6.5, 7]
      (bounds - V[1.5, 7.3, 1]).should eq Bounds.new(V[4.5, -6.3, -1], S[6, 6.5, 7])
    end
  end

  # describe "#*" do
  #   it "multiplies a bounds's size by a number" do
  #     (Bounds[1, 2, 3] * 3).should eq Bounds[3, 6, 9]

  #     bounds = Bounds.new V[6, 1, 0], S[1.3, 6.5, 8.2]
  #     (bounds * 2.5).should eq Bounds.new(V[6, 1, 0], S[3.25, 16.25, 20.5])
  #   end
  # end

  # describe "#/" do
  #   it "divides a bounds's size by a number" do
  #     (Bounds[3, 6, 9] / 3).should eq Bounds[1, 2, 3]

  #     bounds = Bounds.new V[6, 1, 0], S[1.5, 5, 10]
  #     (bounds / 0.25).should eq Bounds.new(V[6, 1, 0], S[6, 20, 40])
  #   end
  # end

  describe "#center" do
    it "returns the center of the bounds" do
      Bounds[10, 20, 30].center.should eq V[5, 10, 15]
      Bounds.new(V[1, 2, 3], S[6, 3, 23]).center.should eq V[4, 3.5, 14.5]
    end
  end

  describe "#includes?" do
    it "tells if a vector is within the primary unit cell" do
      Bounds[10, 20, 30].includes?(V[1, 2, 3]).should be_true
      Bounds.new(V[1, 2, 3], S[6, 3, 23]).includes?(V[3, 2.1, 20]).should be_true
      Bounds[10, 20, 30].includes?(V[-1, 2, 3]).should be_false
      Bounds.new(V[1, 2, 3], S[6, 3, 23]).includes?(V[2.4, 1.8, 23.1]).should be_false
    end

    it "tells if a vector is within the primary unit cell (non-orthogonal)" do
      lattice = Bounds.new S[23.803, 23.828, 5.387], 90, 90, 120
      lattice.includes?(V[10, 20, 2]).should be_true
      lattice.includes?(V[0, 0, 0]).should be_true
      lattice.includes?(V[30, 30, 10]).should be_false
      lattice.includes?(V[-3, 10, 2]).should be_true
      lattice.includes?(V[-3, 2, 2]).should be_false
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the bounds" do
      Bounds[10, 20, 30].volume.should eq 6_000
      Bounds.new(V[1, 2, 3], S[6, 3, 23]).volume.should eq 414
    end
  end
end
