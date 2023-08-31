require "../spec_helper"

describe Chem::Spatial::Direction do
  describe "#includes?" do
    Chem::Spatial::Direction::X.includes?(:x).should eq true
    Chem::Spatial::Direction::Y.includes?(:x).should eq false
    Chem::Spatial::Direction::XY.includes?(:x).should eq true
    Chem::Spatial::Direction::YZ.includes?(:x).should eq false
    Chem::Spatial::Direction::XYZ.includes?(:x).should eq true
    Chem::Spatial::Direction::XY.includes?(:xy).should eq true
    Chem::Spatial::Direction::X.includes?(:xy).should eq false
    Chem::Spatial::Direction::XY.includes?(:xy).should eq true
    Chem::Spatial::Direction::XZ.includes?(:xy).should eq false
    Chem::Spatial::Direction::XYZ.includes?(:xy).should eq true
  end

  describe "#to_vector" do
    Chem::Spatial::Direction::Y.to_vector.should eq vec3(0, 1, 0)
    Chem::Spatial::Direction::XY.to_vector.should eq vec3(1, 1, 0).normalize
    Chem::Spatial::Direction::XYZ.to_vector.should eq vec3(1, 1, 1).normalize
  end
end
