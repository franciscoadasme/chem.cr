require "../spec_helper"

describe Chem::Spatial::AffineTransform do
  describe ".new" do
    it "creates an identity transformation" do
      Tf.new.should eq Tf.new(M.identity(4))
    end

    it "creates a transformation with a 3x3 matrix" do
      transform = Tf.new M[[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      expected = Tf.new M[[1, 2, 3, 0], [4, 5, 6, 0], [7, 8, 9, 0], [0, 0, 0, 1]]
      transform.should eq expected
    end

    it "fails when passed a non-3x3 or 4x4 matrix" do
      expect_raises Chem::Spatial::Error, "Invalid transformation matrix" do
        Tf.new M[[1, 2, 3], [4, 5, 6]]
      end
    end
  end

  describe ".scaling" do
    it "returns a scaling transformation" do
      transform = Tf.scaling by: 1.5
      transform.should eq Tf.new(M.diagonal(1.5, 1.5, 1.5, 1))
    end

    it "returns a scaling transformation with per-axis factors" do
      transform = Tf.scaling by: {1, 2, 3}
      transform.should eq Tf.new(M.diagonal(1, 2, 3, 1))
    end
  end

  describe ".translation" do
    it "returns a translation transformation" do
      transform = Tf.translation by: V[1, 2, 3]
      expected = Tf.new M[[1, 0, 0, 1], [0, 1, 0, 2], [0, 0, 1, 3], [0, 0, 0, 1]]
      transform.should eq expected
    end
  end

  describe "#*" do
    it "transforms a vector" do
      Tf.translation(by: V[1, -2, 3]).*(V[0, 0, 0]).should eq V[1, -2, 3]
      Tf.scaling(by: {4.5, 1, 2.3}).*(V[1, 2, 3]).should be_close V[4.5, 2, 6.9], 1e-8
    end

    it "combines two transformations" do
      tr = Tf.scaling(by: 2) * Tf.translation(by: V[1, 2, 3])
      tr.should eq Tf.new(M[[2, 0, 0, 2], [0, 2, 0, 4], [0, 0, 2, 6], [0, 0, 0, 1]])
    end

    it "combines two transformations (reversed)" do
      tr = Tf.translation(by: V[1, 2, 3]) * Tf.scaling(by: 2)
      tr.should eq Tf.new(M[[2, 0, 0, 1], [0, 2, 0, 2], [0, 0, 2, 3], [0, 0, 0, 1]])
    end
  end

  describe "#<<" do
    it "combines two transformations in-place" do
      tr = Tf.scaling(by: 2)
      tr << Tf.translation(by: V[1, 2, 3])
      tr.should eq Tf.new(M[[2, 0, 0, 1], [0, 2, 0, 2], [0, 0, 2, 3], [0, 0, 0, 1]])
    end
  end

  describe "#inv" do
    it "returns the inverse of the transformation" do
      Tf.scaling(2.41).inv.should eq Tf.scaling(1 / 2.41)
    end
  end

  describe "#scale" do
    it "returns the transformation plus scaling" do
      transform = Tf.translation by: V[0.2, 0.13, 0.35]
      other = transform.scale by: 0.5
      transform.should eq Tf.translation(by: V[0.2, 0.13, 0.35])
      other.should eq Tf.scaling(by: 0.5) * Tf.translation(by: V[0.2, 0.13, 0.35])
    end
  end

  describe "#scale!" do
    it "adds scaling to the transformation" do
      transform = Tf.translation by: V[0.2, 0.13, 0.35]
      transform.scale! by: 0.5
      transform.should eq Tf.scaling(by: 0.5) * Tf.translation(by: V[0.2, 0.13, 0.35])
    end
  end

  describe "#translate" do
    it "adds translation to the transformation" do
      transform = Tf.new
      other = transform.translate by: V[1, 2, 3]
      transform.should eq Tf.new
      other.should eq Tf.translation(by: V[1, 2, 3])
    end
  end

  describe "#translate!" do
    it "adds translation to the transformation" do
      transform = Tf.new
      transform.translate! by: V[1, 2, 3]
      transform.should eq Tf.translation(by: V[1, 2, 3])
    end
  end
end
