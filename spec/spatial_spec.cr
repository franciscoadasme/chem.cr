require "./spec_helper"

describe Chem::Spatial do
  v1 = vec3(3.0, 4.0, 0.0)
  v2 = vec3(1.0, 2.0, 3.0)

  describe ".angle" do
    it "returns the angle between three vectors" do
      a = vec3(9.792, 7.316, 11.31)
      b = vec3(9.021, 7.918, 12.368)
      c = vec3(8.58, 9.109, 12.362)
      Chem::Spatial.angle(a, b, c).should be_close 125.038109, 1e-6
    end

    context "given a non-orthogonal cell" do
      it "returns minimum image convention's angle" do
        cell = Chem::Spatial::Parallelepiped.new({8.497, 43.560, 53.640}, {85.149, 81.972, 76.480})
        [
          {vec3(10.683, 3.591, 15.02),
           vec3(11.078, 4.897, 15.343),
           vec3(3.775, 5.420, 14.839),
           120.408979},
          {vec3(9.555289, 9.838655, 18.734480),
           vec3(10.217254, 9.477283, 17.936636),
           vec3(11.142755, 9.133494, 18.416052),
           107.103893},
          {vec3(17.561918, 42.708153, 11.227142),
           vec3(7.452369, 1.107032, 10.529989),
           vec3(8.070801, 0.735140, 9.680935),
           108.222383,
          },
        ].each do |(a, b, c, expected)|
          Chem::Spatial.angle(cell, a, b, c).should be_close expected, 1e-6
        end
      end
    end
  end

  describe ".distance" do
    it "returns the distance between two quaternions" do
      q1 = Chem::Spatial::Quat[1, 0, 0, 0]
      q2 = Chem::Spatial::Quat[0.5, 0.5, 0.5, 0.5]
      Chem::Spatial.distance(q1, q2).should be_close 2.094395102393196, 1e-15

      q1 = Chem::Spatial::Quat.rotation(vec3(1, 1, 0), 60)
      q2 = Chem::Spatial::Quat.rotation(vec3(1, 1, 0), 180)
      Chem::Spatial.distance(q1, q2).degrees.should be_close 120, 1e-12

      q1 = Chem::Spatial::Quat.rotation(vec3(1, 1, 0), -60)
      q2 = Chem::Spatial::Quat.rotation(vec3(1, 1, 0), 180)
      Chem::Spatial.distance(q1, q2).degrees.should be_close 120, 1e-12

      Chem::Spatial.distance(q1, q1).degrees.should be_close 0, 1e-12
    end
  end

  describe ".dihedral" do
    p1 = vec3(8.396, 5.030, 1.599)
    p2 = vec3(6.979, 5.051, 1.255)
    p3 = vec3(6.107, 5.604, 2.405)
    p4 = vec3(5.156, 4.761, 2.902)
    p5 = vec3(4.273, 5.157, 3.991)
    p6 = vec3(3.426, 6.387, 3.631)
    p7 = vec3(2.613581, 6.909747, 4.371246)

    it "returns the dihedral angle between three vectors" do
      Chem::Spatial.dihedral(p1, p2, p3, p4).should be_close -119.99403249, 1e-8
      Chem::Spatial.dihedral(p3, p4, p5, p6).should be_close 59.96536627, 1e-8
      Chem::Spatial.dihedral(p4, p5, p6, p7).should be_close -179.99997738, 1e-8
    end

    context "given an orthogonal cell" do
      it "returns the dihedral angle using minimum-image convention" do
        cell = Chem::Spatial::Parallelepiped.new({8.77, 9.5, 24.74}, {88.22, 80, 70.34})
        [
          {
            vec3(12.305217, 5.828416, 13.900538),
            vec3(11.346216, 5.428415, 12.976539),
            vec3(10.297216, 4.611416, 13.357537),
            vec3(10.218218, 4.169416, 14.671537),
            -1.147971,
          },
          {
            vec3(10.642056, 1.612213, 17.949539),
            vec3(11.487057, 1.516212, 19.189539),
            vec3(3.994056, 0.691212, 19.091537),
            vec3(4.774056, 1.122212, 17.841537),
            49.13,
          },
          {
            vec3(10.998161, 5.544204, 5.704),
            vec3(10.404161, 7.649203, 6.601),
            vec3(8.769001, 1.017, 6.131),
            vec3(9.765001, 1.086, 5.126),
            14.647226,
          },
          {
            vec3(10.013162, 6.172204, 2.062),
            vec3(10.640162, 5.509203, 0.89),
            vec3(6.923217, 5.407415, 24.324539),
            vec3(7.546217, 4.534415, 23.237539),
            176.497757,
          },
        ].each do |(a, b, c, d, expected)|
          Chem::Spatial.dihedral(cell, a, b, c, d).should be_close expected, 1e-2
        end
      end
    end
  end

  describe ".distance2" do
    context "given a orthogonal cell" do
      it "returns minimum image convention's distance" do
        cell = Chem::Spatial::Parallelepiped.new({10, 20, 30})
        [
          {vec3(1, 1, 1), vec3(5, 5, 5), 47.999999},
          {vec3(1, 1, 1), vec3(9, 18, 27), 29.0},
        ].each do |(a, b, expected)|
          Chem::Spatial.distance2(cell, a, b).should be_close expected, 1e-3
        end
      end
    end

    context "given a non-orthogonal cell" do
      it "returns minimum image convention's distance" do
        cell = Chem::Spatial::Parallelepiped.new({8.77, 9.5, 24.74}, {88.22, 80, 70.34})
        [
          {vec3(0.82, 1.29, 20.12), vec3(8.15, 1.41, 19.61), 2.3481},
          {vec3(3.37, 3.04, 16.5), vec3(5.35, 4.07, 17.456), 5.895236},
          {vec3(0.4, 1.12, 12.79), vec3(8.55, 1.99, 13.88), 2.3294},
        ].each do |(a, b, expected)|
          Chem::Spatial.distance2(cell, a, b).should be_close expected, 1e-6
        end
      end
    end
  end
end
