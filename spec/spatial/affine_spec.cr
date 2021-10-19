require "../spec_helper"

describe Chem::Spatial::AffineTransform do
  describe ".new" do
    it "creates an identity transformation" do
      Tf.new.to_a.should eq [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]
    end

    it "creates a transformation" do
      transform = Tf.new Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9]
      transform.to_a.should eq [1, 4, 7, 0, 2, 5, 8, 0, 3, 6, 9, 0, 0, 0, 0, 1]
    end

    it "creates a transformation with a translation vector" do
      transform = Tf.new Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9], Vec3[1, 2, 3]
      transform.to_a.should eq [1, 4, 7, 1, 2, 5, 8, 2, 3, 6, 9, 3, 0, 0, 0, 1]
    end
  end

  describe ".scaling" do
    it "returns a scaling transformation" do
      expected = [1.5, 0, 0, 0, 0, 1.5, 0, 0, 0, 0, 1.5, 0, 0, 0, 0, 1]
      Tf.scaling(by: 1.5).to_a.should eq expected
    end

    it "returns a scaling transformation with per-axis factors" do
      expected = [1, 0, 0, 0, 0, 2, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1]
      Tf.scaling(by: {1, 2, 3}).to_a.should eq expected
    end
  end

  describe ".translation" do
    it "returns a translation transformation" do
      expected = [1, 0, 0, 1, 0, 1, 0, 2, 0, 0, 1, 3, 0, 0, 0, 1]
      Tf.translation(by: Vec3[1, 2, 3]).to_a.should eq expected
    end
  end

  describe "#*" do
    it "transforms a vector" do
      (Tf.translation(by: Vec3[1, -2, 3]) * Vec3[0, 0, 0]).should eq Vec3[1, -2, 3]
      (Tf.scaling(by: {4.5, 1, 2.3}) * Vec3[1, 2, 3]).should be_close Vec3[4.5, 2, 6.9], 1e-8
    end

    it "combines two transformations" do
      transform = Tf.scaling(by: 2) * Tf.translation(by: Vec3[1, 2, 3])
      transform.to_a.should eq [2, 0, 0, 2, 0, 2, 0, 4, 0, 0, 2, 6, 0, 0, 0, 1]
    end

    it "combines two transformations (reversed)" do
      transform = Tf.translation(by: Vec3[1, 2, 3]) * Tf.scaling(by: 2)
      transform.to_a.should eq [2, 0, 0, 1, 0, 2, 0, 2, 0, 0, 2, 3, 0, 0, 0, 1]
    end
  end

  describe "#inv" do
    it "returns the inverse of the transformation" do
      Tf.scaling(2.41).inv.should eq Tf.scaling(1 / 2.41)
    end
  end

  describe "#scale" do
    it "scales the transformation" do
      transform = Tf.translation by: Vec3[0.2, 0.13, 0.35]
      expected = Tf.scaling(by: 0.5) * Tf.translation(by: Vec3[0.2, 0.13, 0.35])
      transform.scale(by: 0.5).should eq expected
    end
  end

  describe "#translate" do
    it "translates the transformation" do
      offset = Vec3[1, 2, 3]
      Tf.new.translate(by: offset).should eq Tf.translation(by: offset)
    end
  end
end
