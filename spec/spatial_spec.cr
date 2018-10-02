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
      Chem::Spatial.distance(v1.inverse, v2).should eq Math.sqrt(61)
    end
  end

  describe ".squared_distance" do
    it "returns the squared distance between two vectors" do
      Chem::Spatial.squared_distance(v1, v2).should eq 17
      Chem::Spatial.squared_distance(v1.inverse, v2).should eq 61
    end
  end
end
