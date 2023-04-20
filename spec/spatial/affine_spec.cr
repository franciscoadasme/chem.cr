require "../spec_helper"

describe Chem::Spatial::AffineTransform do
  describe ".aligning" do
    it "returns a transformation that aligns two vectors" do
      u = vec3(1, 2, 4)
      v = vec3(-1, 1, 25)
      transform = Chem::Spatial::AffineTransform.aligning(u, v)
      (transform * u).normalize.should eq v.normalize
    end

    it "returns a transformation that aligns two pairs of vectors" do
      transform = Chem::Spatial::AffineTransform.rotation(vec3(1, 2, 3), 65)
      u = vec3(-5, 1, 3)
      v = vec3(6, 2, 62)
      uu = transform * u
      vv = transform * v
      transform = Chem::Spatial::AffineTransform.aligning({uu, vv}, to: {u, v})
      (transform * uu).normalize.should be_close u.normalize, 1e-15
      (transform * vv).normalize.should be_close v.normalize, 1e-15
    end

    it "returns a transformation that aligns two coordinate sets" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      transform = Chem::Spatial::AffineTransform.aligning(s[1], s[0])
      s[1].coords.transform! transform
      Chem::Spatial.rmsd(s[1], s[0]).should be_close 3.463298, 1e-6
    end

    it "returns the identity matrix for the same coordinate set" do
      s = Array(Chem::Structure).read spec_file("E20_conformers.mol2")
      transform = Chem::Spatial::AffineTransform.aligning(s[0], s[0])
      transform.should eq Chem::Spatial::AffineTransform.identity
    end
  end

  describe ".identity" do
    it "creates an identity transformation" do
      transform = Chem::Spatial::AffineTransform.identity
      transform.linear_map.should eq Chem::Spatial::Mat3.identity
      transform.offset.should eq [0, 0, 0]
    end
  end

  describe ".rotation" do
    it "returns a rotation transformation" do
      transform = Chem::Spatial::AffineTransform.rotation(vec3(1, 0, 0), 90)
      transform.linear_map.should be_close Chem::Spatial::Mat3[
        {1, 0, 0},
        {0, 0, -1},
        {0, 1, 0},
      ], 1e-15
      transform.offset.should eq [0, 0, 0]

      transform = Chem::Spatial::AffineTransform.rotation(vec3(0.67, 0.68, 0.3), 180)
      transform.linear_map.should be_close Chem::Spatial::Mat3[
        {-0.1033656, 0.9100170, 0.4014781},
        {0.9100170, -0.0764007, 0.4074703},
        {0.4014781, 0.4074703, -0.8202337},
      ], 1e-7
      transform.offset.should eq [0, 0, 0]

      transform = Chem::Spatial::AffineTransform.rotation(vec3(0.67, 0.68, 0.3), 360)
      transform.linear_map.should be_close Chem::Spatial::Mat3.identity, 1e-15
      transform.offset.should eq [0, 0, 0]

      transform = Chem::Spatial::AffineTransform.rotation(vec3(0.31, 0.91, -0.28), 46)
      transform.linear_map.should be_close Chem::Spatial::Mat3[
        {0.7239256, 0.2870673, 0.6273150},
        {-0.1152403, 0.9468561, -0.3003053},
        {-0.6801848, 0.1451067, 0.7185351},
      ], 1e-7
      transform.offset.should eq [0, 0, 0]
    end

    it "returns the rotation by Euler angles" do
      transform = Chem::Spatial::AffineTransform.rotation(123, 4, 96)
      transform.linear_map.should be_close Chem::Spatial::Mat3[
        {-0.1042738, -0.9920993, 0.0697565},
        {-0.5477706, -0.0012519, -0.8366276},
        {0.8301050, -0.1254489, -0.5433123},
      ], 1e-7
      transform.offset.should eq [0, 0, 0]
    end
  end

  describe ".scaling" do
    it "returns a scaling transformation" do
      transform = Chem::Spatial::AffineTransform.scaling(1.5)
      transform.linear_map.should eq Chem::Spatial::Mat3.diagonal(1.5)
      transform.offset.should eq [0, 0, 0]
    end

    it "returns a scaling transformation with per-axis factors" do
      transform = Chem::Spatial::AffineTransform.scaling(1, 3, 4)
      transform.linear_map.should eq Chem::Spatial::Mat3.diagonal(1, 3, 4)
      transform.offset.should eq [0, 0, 0]
    end
  end

  describe ".translation" do
    it "returns a translation transformation" do
      transform = Chem::Spatial::AffineTransform.translation(vec3(1, 2, 3))
      transform.linear_map.should eq Chem::Spatial::Mat3.identity
      transform.offset.should eq [1, 2, 3]
    end
  end

  describe "#*" do
    it "transforms a vector" do
      (Chem::Spatial::AffineTransform.translation(vec3(1, -2, 3)) * vec3(0, 0, 0)).should eq [1, -2, 3]
      (Chem::Spatial::AffineTransform.scaling(4.5, 1, 2.3) * vec3(1, 2, 3)).should be_close [4.5, 2, 6.9], 1e-8
    end

    it "transforms a vector (inverse)" do
      transform = Chem::Spatial::AffineTransform.scaling(4.5, 1, 2.3)
      (vec3(1, 2, 3) * transform).should eq [1 / 4.5, 2, 3 / 2.3]
    end

    it "combines two transformations" do
      a = Chem::Spatial::AffineTransform.translation(vec3(1, 2, 3))
      b = Chem::Spatial::AffineTransform.scaling(2)
      transform = b * a
      transform.linear_map.should eq Chem::Spatial::Mat3[{2, 0, 0}, {0, 2, 0}, {0, 0, 2}]
      transform.offset.should eq [2, 4, 6]
    end

    it "combines two transformations (reversed)" do
      a = Chem::Spatial::AffineTransform.translation(vec3(1, 2, 3))
      b = Chem::Spatial::AffineTransform.scaling(2)
      transform = a * b
      transform.linear_map.should eq Chem::Spatial::Mat3[{2, 0, 0}, {0, 2, 0}, {0, 0, 2}]
      transform.offset.should eq [1, 2, 3]
    end
  end

  describe "#inv" do
    it "returns the inverse of the transformation" do
      transform = Chem::Spatial::AffineTransform.scaling(2.41)
      (transform.inv * transform).should eq Chem::Spatial::AffineTransform.identity
      (transform * transform.inv).should eq Chem::Spatial::AffineTransform.identity
    end
  end

  describe "#rotate" do
    it "rotates the transformation" do
      rotaxis = Chem::Spatial::Vec3.rand
      angle = rand * 180
      transform = Chem::Spatial::AffineTransform.identity.translate(vec3(1, 2, 3)).scale(2.5)
      expected = Chem::Spatial::AffineTransform.rotation(rotaxis, angle) * transform
      transform.rotate(rotaxis, angle).should eq expected
    end
  end

  describe "#rotation" do
    it "returns the rotation component" do
      transform = Chem::Spatial::AffineTransform.rotation(50, 10, 5).translate(vec3(1, 2, 3))
      rot = transform.rotation
      rot.should be_a Chem::Spatial::AffineTransform
      rot.linear_map.should eq transform.linear_map
      rot.offset.should eq vec3(0, 0, 0)
    end
  end

  describe "#scale" do
    it "scales the transformation" do
      offset = vec3(0.2, 0.13, 0.35)
      transform = Chem::Spatial::AffineTransform.translation offset
      transform = transform.scale(0.5)
      transform.linear_map.should eq Chem::Spatial::Mat3.diagonal(0.5)
      transform.offset.should eq offset * 0.5
    end

    it "scales the transformation wit different factors" do
      factors = {0.35, 0.26, 2.5}
      offset = vec3(0.2, 0.13, 0.35)
      transform = Chem::Spatial::AffineTransform.translation offset
      transform = transform.scale(*factors)
      transform.linear_map.should eq Chem::Spatial::Mat3.diagonal(*factors)
      transform.offset.should eq offset * vec3(*factors)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      expected = "[\
        [ 4.440892e-16 -1.931852  0.5176381 -2.310789 ], \
        [ 1.414214 -0.3660254 -1.366025 -3.415913 ], \
        [ 1.414214  0.3660254  1.366025  6.244341 ], \
        [0  0  0  1]]"
      transform = Chem::Spatial::AffineTransform.translation(vec3(1, 2, 3)).scale(2).rotate(45, 15, 90)
      transform.to_s.should eq expected
    end
  end

  describe "#translate" do
    it "translates the transformation" do
      offset = vec3(1, 2, 3)
      transform = Chem::Spatial::AffineTransform.identity.translate(offset)
      transform.linear_map.should eq Chem::Spatial::Mat3.identity
      transform.offset.should eq offset
    end
  end

  describe "#translation" do
    it "returns the translation component" do
      transform = Chem::Spatial::AffineTransform.rotation(50, 10, 5).translate(vec3(1, 2, 3))
      trans = transform.translation
      trans.should be_a Chem::Spatial::AffineTransform
      trans.linear_map.should eq Chem::Spatial::Mat3.identity
      trans.offset.should eq vec3(1, 2, 3)
    end
  end
end
