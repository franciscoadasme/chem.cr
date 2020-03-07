require "../spec_helper"

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

    it "returns the angle between three vectors" do
      a = V[9.792, 7.316, 11.31]
      b = V[9.021, 7.918, 12.368]
      c = V[8.58, 9.109, 12.362]
      Chem::Spatial.angle(a, b, c).should be_close 125.038109, 1e-6
    end

    context "given a non-orthogonal cell" do
      it "returns minimum image convention's angle" do
        lattice = Lattice.new S[8.497, 43.560, 53.640], 85.149, 81.972, 76.480
        [
          {V[10.683, 3.591, 15.02],
           V[11.078, 4.897, 15.343],
           V[3.775, 5.420, 14.839],
           120.408979},
          {V[9.555289, 9.838655, 18.734480],
           V[10.217254, 9.477283, 17.936636],
           V[11.142755, 9.133494, 18.416052],
           107.103893},
          {V[17.561918, 42.708153, 11.227142],
           V[7.452369, 1.107032, 10.529989],
           V[8.070801, 0.735140, 9.680935],
           108.222383,
          },
        ].each do |(a, b, c, expected)|
          Chem::Spatial.angle(a, b, c, lattice).should be_close expected, 1e-6
        end
      end
    end
  end

  describe ".distance" do
    it "returns the distance between two vectors" do
      Chem::Spatial.distance(v1, v2).should eq Math.sqrt(17)
      Chem::Spatial.distance(v1.inv, v2).should eq Math.sqrt(61)
    end

    it "returns the distance between two quaternions" do
      q1 = Q[1, 0, 0, 0]
      q2 = Q[0.5, 0.5, 0.5, 0.5]
      Chem::Spatial.distance(q1, q2).should be_close 2.094395102393196, 1e-15

      q1 = Q.rotation(V[1, 1, 0], 60)
      q2 = Q.rotation(V[1, 1, 0], 180)
      Chem::Spatial.distance(q1, q2).degrees.should be_close 120, 1e-12

      q1 = Q.rotation(V[1, 1, 0], -60)
      q2 = Q.rotation(V[1, 1, 0], 180)
      Chem::Spatial.distance(q1, q2).degrees.should be_close 120, 1e-12

      Chem::Spatial.distance(q1, q1).degrees.should be_close 0, 1e-12
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

    context "given a orthogonal cell" do
      it "returns minimum image convention's distance" do
        l = Lattice.new S[10, 20, 30]
        [
          {V[1, 1, 1], V[5, 5, 5], 47.999999},
          {V[1, 1, 1], V[9, 18, 27], 29.0},
        ].each do |(a, b, expected)|
          Chem::Spatial.squared_distance(a, b, l).should be_close expected, 1e-3
        end
      end
    end

    context "given a non-orthogonal cell" do
      it "returns minimum image convention's distance" do
        l = Lattice.new S[8.77, 9.5, 24.74], 88.22, 80, 70.34
        [
          {V[0.82, 1.29, 20.12], V[8.15, 1.41, 19.61], 2.3481},
          {V[3.37, 3.04, 16.5], V[5.35, 4.07, 17.456], 5.895236},
          {V[0.4, 1.12, 12.79], V[8.55, 1.99, 13.88], 2.3294},
        ].each do |(a, b, expected)|
          Chem::Spatial.squared_distance(a, b, l).should be_close expected, 1e-6
        end
      end
    end
  end
end
