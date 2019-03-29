require "../spec_helper"

alias Basis = Chem::Linalg::Basis

describe Chem::Linalg::Basis do
  describe ".standard" do
    it "returns the standard basis" do
      Basis.standard.should eq Basis.new(V.x, V.y, V.z)
    end
  end

  describe "#standard?" do
    it "returns true when basis is standard" do
      Basis.standard.standard?.should be_true
    end

    it "returns false when basis is not standard" do
      Basis.new(V[1, 1, 0], V[2, 0, 0], V[0.4, 1, 0]).standard?.should be_false
    end
  end

  describe "#transform" do
    it "returns the identity affine transformation to change the basis to itself" do
      basis = Basis.new V[-1, 1, 0], V[-1, 0, 1], V[1, 1, 1]
      basis.transform(to: basis).should eq Tf.new
    end

    it "returns the affine transformation to change a basis to standard" do
      basis = Basis.new V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]
      transform = Tf.new M[
        [1, 4, 7],
        [2, 5, 8],
        [3, 6, 9],
      ]
      basis.transform(to: Basis.standard).should eq transform
    end

    it "returns the affine transformation to change a basis to another" do
      basis = Basis.new V[1.2, 0, 1.8], V[0, 1.2, 1.2], V[1.6, 0, 1.6]
      other = Basis.new V[0, 0.4, 0], V[1.2, 1, 1.2], V[1.4, 1.6, 1]
      transform = Tf.new M[
        [-0.875, 6.25, -10.0/3],
        [2.75, 3.5, 4.0/3],
        [-1.5, -3, 0],
      ]
      basis.transform(to: other).should be_close transform, 1e8
    end

    it "returns the affine transformation to change the standard basis to another" do
      basis = Basis.new V[-1, 1, 0], V[-1, 0, 1], V[1, 1, 1]
      transform = Tf.new M[
        [-1.0/3, 2.0/3, -1.0/3],
        [-1.0/3, -1.0/3, 2.0/3],
        [1.0/3, 1.0/3, 1.0/3],
      ]
      Basis.standard.transform(to: basis).should be_close transform, 1e8
    end
  end

  describe "#to_m" do
    it "returns a matrix filled with basis column vectors" do
      Basis.standard.to_m.should eq M[[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    end
  end
end
