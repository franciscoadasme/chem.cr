require "./spec_helper"

describe Chem::Spatial do
  v1 = Vector[3.0, 4.0, 0.0]
  v2 = Vector[1.0, 2.0, 3.0]

  describe ".angle" do
    it "returns the angle between two vectors" do
      Chem::Spatial.angle(Vector[1, 0, 0], Vector[-1, -1, 0]).should eq 135
      Chem::Spatial.angle(Vector[3, 4, 0], Vector[4, 4, 2]).should eq 21.039469781317237
      Chem::Spatial.angle(Vector[1, 0, 3], Vector[5, 5, 0]).should eq 77.07903361841643
    end

    it "returns zero when vectors are parallel" do
      Chem::Spatial.angle(Vector[1, 0, 0], Vector[2, 0, 0]).should eq 0
    end

    it "returns 90 degrees when vectors are perpendicular to each other" do
      Chem::Spatial.angle(Vector[1, 0, 0], Vector[0, 1, 0]).should eq 90
    end
  end

  describe ".distance" do
    it "returns the distance between two vectors" do
      Chem::Spatial.distance(v1, v2).should eq Math.sqrt(17)
      Chem::Spatial.distance(v1.inv, v2).should eq Math.sqrt(61)
    end
  end

  describe ".dihedral" do
    p1 = Vector[8.396, 5.030, 1.599]
    p2 = Vector[6.979, 5.051, 1.255]
    p3 = Vector[6.107, 5.604, 2.405]
    p4 = Vector[5.156, 4.761, 2.902]
    p5 = Vector[4.273, 5.157, 3.991]
    p6 = Vector[3.426, 6.387, 3.631]
    p7 = Vector[2.613581, 6.909747, 4.371246]

    it "returns the dihedral angle between three vectors" do
      Chem::Spatial.dihedral(p1, p2, p3, p4).should be_close -119.99403249, 1e-8
      Chem::Spatial.dihedral(p3, p4, p5, p6).should be_close 59.96536627, 1e-8
      Chem::Spatial.dihedral(p4, p5, p6, p7).should be_close -179.99997738, 1e-8
    end
  end

  describe ".squared_distance" do
    it "returns the squared distance between two vectors" do
      Chem::Spatial.squared_distance(v1, v2).should eq 17
      Chem::Spatial.squared_distance(v1.inv, v2).should eq 61
    end
  end
end
