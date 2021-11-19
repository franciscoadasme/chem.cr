require "../spec_helper"

describe Chem::Spatial::Bounds do
  describe ".[]" do
    it "returns a bounds with the given size placed at origin" do
      bounds = Chem::Spatial::Bounds[1, 2, 3]
      bounds.origin.should eq [0, 0, 0]
      bounds.size.should eq Chem::Spatial::Size3[1, 2, 3]
      bounds.basis.should eq Chem::Spatial::Mat3.diagonal(1, 2, 3)
    end
  end

  describe "#center" do
    it "returns the center of the bounds" do
      Chem::Spatial::Bounds[10, 20, 30].center.should eq [5, 10, 15]
      Chem::Spatial::Bounds[6, 3, 23].translate(Chem::Spatial::Vec3[1, 2, 3]).center.should eq [4, 3.5, 14.5]
    end
  end

  describe "#each_vertex" do
    it "yields bounds' vertices" do
      bounds = Chem::UnitCell.new({8.77, 9.5, 24.74}, {88.22, 80, 70.34}).bounds
      bounds = bounds.translate -bounds.center
      vertices = [] of Chem::Spatial::Vec3
      bounds.each_vertex { |vec| vertices << vec }
      vertices.size.should eq 8
      vertices.should be_close [
        [-8.131, -4.114, -12.177],
        [-3.835, -4.832, 12.177],
        [-4.935, 4.832, -12.177],
        [-0.639, 4.114, 12.177],
        [0.639, -4.114, -12.177],
        [4.935, -4.832, 12.177],
        [3.835, 4.832, -12.177],
        [8.131, 4.114, 12.177],
      ], 1e-3
    end
  end

  describe "#includes?" do
    it "tells if a vector is within the primary unit cell" do
      Chem::Spatial::Bounds[10, 20, 30].includes?(Chem::Spatial::Vec3[1, 2, 3]).should be_true
      Chem::Spatial::Bounds[6, 3, 23].translate(Chem::Spatial::Vec3[1, 2, 3]).includes?(Chem::Spatial::Vec3[3, 2.1, 20]).should be_true
      Chem::Spatial::Bounds[10, 20, 30].includes?(Chem::Spatial::Vec3[-1, 2, 3]).should be_false
      Chem::Spatial::Bounds[6, 3, 23].translate(Chem::Spatial::Vec3[1, 2, 3]).includes?(Chem::Spatial::Vec3[2.4, 1.8, 23.1]).should be_false
    end

    it "tells if a vector is within the primary unit cell (non-orthogonal)" do
      bounds = Chem::UnitCell.new({23.803, 23.828, 5.387}, {90, 90, 120}).bounds
      bounds.includes?(Chem::Spatial::Vec3[10, 20, 2]).should be_true
      bounds.includes?(Chem::Spatial::Vec3[0, 0, 0]).should be_true
      bounds.includes?(Chem::Spatial::Vec3[30, 30, 10]).should be_false
      bounds.includes?(Chem::Spatial::Vec3[-3, 10, 2]).should be_true
      bounds.includes?(Chem::Spatial::Vec3[-3, 2, 2]).should be_false
    end

    context "given a bounds" do
      it "returns true when enclosed" do
        bounds = Chem::UnitCell.hexagonal(10, 10).bounds
        bounds.includes?(Chem::Spatial::Bounds[5, 4, 6]).should be_true
        bounds.includes?(Chem::Spatial::Bounds[5, 4, 6].translate(Chem::Spatial::Vec3[1, 2, 3])).should be_true
      end

      it "returns false when intersected" do
        bounds = Chem::UnitCell.hexagonal(10, 10).bounds
        bounds.includes?(Chem::Spatial::Bounds[5, 4, 6].translate(Chem::Spatial::Vec3[-1, 2, -4.3])).should be_false
      end

      it "returns false when out of bounds" do
        bounds = Chem::UnitCell.hexagonal(10, 10).bounds
        bounds.includes?(Chem::Spatial::Bounds[5, 4, 6].translate(Chem::Spatial::Vec3[-1, 2, -4.3])).should be_false
      end
    end
  end

  describe "#max" do
    context "given an orthogonal bounds" do
      it "returns the maximum edge" do
        Chem::Spatial::Bounds[10, 5, 8].max.should eq Chem::Spatial::Vec3[10, 5, 8]
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns the maximum edge" do
        bounds = Chem::UnitCell.hexagonal(10, 12).bounds.translate(Chem::Spatial::Vec3[1.5, 3, -0.4])
        bounds.max.should be_close Chem::Spatial::Vec3[6.5, 11.66, 11.6], 1e-3
      end
    end
  end

  describe "#min" do
    context "given an orthogonal bounds" do
      it "returns the minimum edge (origin)" do
        Chem::Spatial::Bounds[10, 5, 8].min.should eq Chem::Spatial::Vec3[0, 0, 0]
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns the minimum edge (origin)" do
        bounds = Chem::UnitCell.hexagonal(10, 12).bounds.translate(Chem::Spatial::Vec3[1.5, 3, -0.4])
        bounds.min.should eq Chem::Spatial::Vec3[1.5, 3, -0.4]
      end
    end
  end

  describe "#translate" do
    it "translates the origin" do
      cell = Chem::UnitCell.hexagonal(10, 10)
      bounds = cell.bounds.translate(Chem::Spatial::Vec3[-5, 1, 20])
      bounds = bounds.translate(Chem::Spatial::Vec3[1, 2, 10])
      bounds.min.should eq Chem::Spatial::Vec3[-4, 3, 30]
      bounds.size.should be_close Chem::Spatial::Size3[10, 10, 10], 1e-12
      bounds.basis.should eq cell.basis
    end
  end

  describe "#pad" do
    context "given an orthogonal bounds" do
      it "returns a padded bounds" do
        bounds = Chem::Spatial::Bounds[10, 10, 10]
        padded = bounds.pad(2)
        padded.size.should eq Chem::Spatial::Size3[14, 14, 14]
        padded.center.should eq bounds.center
      end
    end

    context "given a non-orthogonal bounds" do
      it "returns a padded bounds" do
        bounds = Chem::UnitCell.new({4, 7, 8.5}, {90, 120, 90}).bounds
        padded = bounds.pad(0.5)
        padded.size.should eq Chem::Spatial::Size3[5, 8, 9.5]
        padded.center.should be_close bounds.center, 1e-15
      end
    end

    it "raises on negative padding" do
      expect_raises ArgumentError, "Negative padding" do
        Chem::Spatial::Bounds[1, 1, 1].pad -5
      end
    end
  end

  describe "#vertices" do
    it "returns bounds' vertices" do
      vertices = Chem::UnitCell.new({10, 10, 10}, {90, 90, 120}).bounds.vertices
      vertices.size.should eq 8
      vertices.should be_close [
        Chem::Spatial::Vec3[0, 0, 0],
        Chem::Spatial::Vec3[0, 0, 10],
        Chem::Spatial::Vec3[-5, 8.660, 0],
        Chem::Spatial::Vec3[-5, 8.660, 10],
        Chem::Spatial::Vec3[10, 0, 0],
        Chem::Spatial::Vec3[10, 0, 10],
        Chem::Spatial::Vec3[5, 8.660, 0],
        Chem::Spatial::Vec3[5, 8.660, 10],
      ], 1e-3
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the bounds" do
      Chem::Spatial::Bounds[10, 20, 30].volume.should eq 6_000
      Chem::UnitCell.hexagonal(5, 8).bounds.volume.should be_close 173.2050807569, 1e-10
      Chem::UnitCell.new({1, 2, 3}, {90, 101.2, 90}).bounds.volume.should be_close 5.8857309321, 1e-10
      Chem::Spatial::Bounds[6, 3, 23].translate(Chem::Spatial::Vec3[1, 2, 3]).volume.should eq 414
    end
  end
end
