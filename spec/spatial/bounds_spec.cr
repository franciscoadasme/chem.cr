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

  describe "#each_vertex" do
    it "yields bounds' vertices" do
      bounds = Bounds.new S[8.77, 9.5, 24.74], 88.22, 80, 70.34
      bounds = bounds.translate -bounds.center
      vertices = [] of Vector
      bounds.each_vertex { |vec| vertices << vec }
      vertices.size.should eq 8
      vertices.should be_close [
        V[-8.131, -4.114, -12.177],
        V[-3.835, -4.832, 12.177],
        V[-4.935, 4.832, -12.177],
        V[-0.639, 4.114, 12.177],
        V[0.639, -4.114, -12.177],
        V[4.935, -4.832, 12.177],
        V[3.835, 4.832, -12.177],
        V[8.131, 4.114, 12.177],
      ], 1e-3
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

    context "given a bounds" do
      it "returns true when enclosed" do
        bounds = Bounds.new S[10, 10, 10], 90, 90, 120
        bounds.includes?(Bounds.new(V[1, 2, 3], S[5, 4, 6])).should be_true
        bounds.includes?(Bounds.new(S[5, 4, 6])).should be_true
      end

      it "returns false when intersected" do
        bounds = Bounds.new S[10, 10, 10], 90, 90, 120
        bounds.includes?(Bounds.new(V[-1, 2, -4.3], S[5, 4, 6])).should be_false
      end

      it "returns false when out of bounds" do
        bounds = Bounds.new S[10, 10, 10], 90, 90, 120
        bounds.includes?(Bounds.new(V[-1, 2, -4.3], S[5, 4, 6])).should be_false
      end
    end
  end

  describe "#max" do
    context "given an orthogonal bounds" do
      it "returns the maximum edge" do
        Bounds[10, 5, 8].max.should eq V[10, 5, 8]
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns the maximum edge" do
        bounds = Bounds.new(V[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120)
        bounds.max.should be_close V[6.5, 11.66, 11.6], 1e-3
      end
    end
  end

  describe "#min" do
    context "given an orthogonal bounds" do
      it "returns the minimum edge (origin)" do
        Bounds[10, 5, 8].min.should eq V[0, 0, 0]
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns the minimum edge (origin)" do
        bounds = Bounds.new(V[1.5, 3, -0.4], S[10, 10, 12], 90, 90, 120)
        bounds.min.should eq V[1.5, 3, -0.4]
      end
    end
  end

  describe "#translate" do
    it "translates the origin" do
      bounds = Bounds.new V[-5, 1, 20], S[10, 10, 10], 90, 90, 120
      bounds = bounds.translate(V[1, 2, 10])
      bounds.min.should eq V[-4, 3, 30]
      bounds.size.should eq S[10, 10, 10]
      bounds.angles.map(&.round).should eq({90, 90, 120})
    end
  end

  describe "#pad" do
    context "given an orthogonal bounds" do
      it "returns a padded bounds" do
        bounds = Bounds[10, 10, 10]
        padded = bounds.pad(2)
        padded.size.should eq S[14, 14, 14]
        padded.center.should eq bounds.center
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns a padded bounds" do
        bounds = Bounds.new(S[4, 7, 8.5], 90, 120, 90)
        padded = bounds.pad(0.5)
        padded.size.should eq S[5, 8, 9.5]
        padded.center.should be_close bounds.center, 1e-15
      end
    end

    it "raises on negative padding" do
      expect_raises ArgumentError, "Padding cannot be negative" do
        Bounds[1, 1, 1].pad -5
      end
    end
  end

  describe "#vertices" do
    it "returns bounds' vertices" do
      vertices = Bounds.new(S[10, 10, 10], 90, 90, 120).vertices
      vertices.size.should eq 8
      vertices.should be_close [
        V[0, 0, 0],
        V[0, 0, 10],
        V[-5, 8.660, 0],
        V[-5, 8.660, 10],
        V[10, 0, 0],
        V[10, 0, 10],
        V[5, 8.660, 0],
        V[5, 8.660, 10],
      ], 1e-3
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the bounds" do
      Bounds[10, 20, 30].volume.should eq 6_000
      Bounds.new(S[5, 5, 8], 90, 90, 120).volume.should be_close 173.2050807569, 1e-10
      Bounds.new(S[1, 2, 3], beta: 101.2).volume.should be_close 5.8857309321, 1e-10
      Bounds.new(V[1, 2, 3], S[6, 3, 23]).volume.should eq 414
    end
  end
end
