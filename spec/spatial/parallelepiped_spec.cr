require "../spec_helper"

describe Chem::Spatial::Parallelepiped do
  describe ".new" do
    it "creates a parallelepiped with vectors" do
      pld = Chem::Spatial::Parallelepiped.new vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1)
      pld.basis.should eq Chem::Spatial::Mat3.basis(
        vec3(1, 0, 0),
        vec3(0, 1, 0),
        vec3(0, 0, 1),
      )
    end

    it "creates a parallelepiped with size" do
      pld = Chem::Spatial::Parallelepiped.new({74.23, 135.35, 148.46})
      pld.basis.should be_close Chem::Spatial::Mat3.basis(
        vec3(74.23, 0, 0),
        vec3(0, 135.35, 0),
        vec3(0, 0, 148.46),
      ), 1e-6
    end

    it "creates a parallelepiped with size and angles" do
      pld = Chem::Spatial::Parallelepiped.new(
        {8.661, 11.594, 21.552}, {86.389999, 82.209999, 76.349998})
      pld.basis.should be_close Chem::Spatial::Mat3.basis(
        vec3(8.661, 0.0, 0.0),
        vec3(2.736071, 11.266532, 0.0),
        vec3(2.921216, 0.687043, 21.342052),
      ), 1e-6
    end
  end

  describe ".[]" do
    it "returns a parallelepiped with the given size placed at origin" do
      pld = Chem::Spatial::Parallelepiped[1, 2, 3]
      pld.origin.should eq [0, 0, 0]
      pld.size.should eq Chem::Spatial::Size3[1, 2, 3]
      pld.basis.should eq Chem::Spatial::Mat3.diagonal(1, 2, 3)
    end
  end

  describe ".cubic" do
    it "returns a cubic parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.cubic(10.1)
      pld.size.should eq [10.1, 10.1, 10.1]
      pld.angles.should eq({90, 90, 90})
    end
  end

  describe ".hexagonal" do
    it "returns a hexagonal parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.hexagonal(1, 2)
      pld.size.should be_close [1, 1, 2], 1e-15
      pld.angles.should be_close({90, 90, 120}, 1e-8)
    end
  end

  describe ".monoclinic" do
    it "returns a monoclinic parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.monoclinic(1, 2, 45)
      pld.size.should eq [1, 1, 2]
      pld.angles.should be_close({90, 45, 90}, 1e-12)
    end
  end

  describe ".orthorhombic" do
    it "returns a orthorhombic parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3)
      pld.size.should eq [1, 2, 3]
      pld.angles.should eq({90, 90, 90})
    end
  end

  describe ".rhombohedral" do
    it "returns a rhombohedral parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.rhombohedral(1, 45)
      pld.size.should eq [1, 1, 1]
      pld.angles.should be_close({45, 45, 45}, 1e-12)
    end
  end

  describe ".tetragonal" do
    it "returns a tetragonal parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.tetragonal(1, 2)
      pld.size.should eq [1, 1, 2]
      pld.angles.should eq({90, 90, 90})
    end
  end

  describe "#angles" do
    it "returns parallelepiped's angles" do
      pld = Chem::Spatial::Parallelepiped.new({1, 2, 3}, {45, 120, 89})
      pld.angles.should be_close({45, 120, 89}, 1e-8)
    end
  end

  describe "#cart" do
    it "returns Cartesian coordinates" do
      pld = Chem::Spatial::Parallelepiped.new({20, 20, 16})
      pld.cart(vec3(0.5, 0.65, 1)).should be_close [10, 13, 16], 1e-15
      pld.cart(vec3(1.5, 0.23, 0.9)).should be_close [30, 4.6, 14.4], 1e-15

      pld = Chem::Spatial::Parallelepiped.new({20, 10, 16})
      pld.cart(vec3(0.5, 0.65, 1)).should be_close [10, 6.5, 16], 1e-15

      pld = Chem::Spatial::Parallelepiped.new(
        vec3(8.497, 0.007, 0.031),
        vec3(10.148, 42.359, 0.503),
        vec3(7.296, 2.286, 53.093))
      pld.cart(vec3(0.724, 0.04, 0.209)).should be_close [8.083, 2.177, 11.139], 1e-3
    end
  end

  describe "#center" do
    it "returns the center of the parallelepiped" do
      Chem::Spatial::Parallelepiped[10, 20, 30].center.should eq [5, 10, 15]
      Chem::Spatial::Parallelepiped.new(vec3(1, 2, 3), {6, 3, 23}).center.should eq [4, 3.5, 14.5]
    end
  end

  describe "#center_at" do
    it "centers the parallelepiped at vector" do
      pld = Chem::Spatial::Parallelepiped.new({10, 20, 30})
      pld.center_at vec3(5, 10, 15)
      pld.center.should eq [5, 10, 15]
    end
  end

  describe "#center_at_origin" do
    it "centers the parallelepiped at the origin" do
      pld = Chem::Spatial::Parallelepiped.new(vec3(2, 5, 23), {10, 20, 30})
      pld = pld.center_at_origin
      pld.center.should eq [0, 0, 0]
    end
  end

  describe "#cubic?" do
    it "tells if the parallelepiped is cubic" do
      Chem::Spatial::Parallelepiped.cubic(1).cubic?.should be_true
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).cubic?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).cubic?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).cubic?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).cubic?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).cubic?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).cubic?.should be_false
    end
  end

  describe "#edges" do
    it "returns every edge as a vector pair" do
      pld = Chem::Spatial::Parallelepiped.hexagonal(10, 5).translate(vec3(5, -12, 4.2))
      pld.edges.zip([
        {vec3(5, -12, 4.2), vec3(15, -12, 4.2)},
        {vec3(5, -12, 4.2), vec3(0, -3.339745962155611, 4.2)},
        {vec3(5, -12, 4.2), vec3(5, -12, 9.2)},
        {vec3(15, -12, 4.2), vec3(10, -3.339745962155611, 4.2)},
        {vec3(15, -12, 4.2), vec3(15, -12, 9.2)},
        {vec3(0, -3.339745962155611, 4.2), vec3(10, -3.339745962155611, 4.2)},
        {vec3(0, -3.339745962155611, 4.2), vec3(0, -3.3397459621556105, 9.2)},
        {vec3(10, -3.339745962155611, 4.2), vec3(10, -3.3397459621556105, 9.2)},
        {vec3(5, -12, 9.2), vec3(15, -12, 9.2)},
        {vec3(5, -12, 9.2), vec3(0, -3.3397459621556105, 9.2)},
        {vec3(15, -12, 9.2), vec3(10, -3.3397459621556105, 9.2)},
        {vec3(0, -3.3397459621556105, 9.2), vec3(10, -3.3397459621556105, 9.2)},
      ]) do |actual, expected|
        actual.should be_close expected, 1e-12
      end
    end
  end

  describe "#each_vertex" do
    it "yields parallelepiped' vertices" do
      pld = Chem::Spatial::Parallelepiped.new({8.77, 9.5, 24.74}, {88.22, 80, 70.34})
      pld = pld.center_at_origin

      vertices = [] of Chem::Spatial::Vec3
      pld.each_vertex { |vec| vertices << vec }
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

  describe "#fract" do
    it "returns fractional coordinates" do
      pld = Chem::Spatial::Parallelepiped.new({10, 20, 30})
      pld.fract(vec3(0, 0, 0)).should eq [0, 0, 0]
      pld.fract(vec3(1, 2, 3)).should be_close [0.1, 0.1, 0.1], 1e-15
      pld.fract(vec3(2, 3, 15)).should be_close [0.2, 0.15, 0.5], 1e-15

      pld = Chem::Spatial::Parallelepiped.new({20, 20, 30})
      pld.fract(vec3(1, 2, 3)).should be_close [0.05, 0.1, 0.1], 1e-15
    end
  end

  describe "#hexagonal?" do
    it "tells if the parallelepiped is hexagonal" do
      Chem::Spatial::Parallelepiped.cubic(1).hexagonal?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).hexagonal?.should be_true
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).hexagonal?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).hexagonal?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).hexagonal?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).hexagonal?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).hexagonal?.should be_false
    end
  end

  describe "#includes?" do
    it "tells if a vector is enclosed" do
      pld = Chem::Spatial::Parallelepiped[10, 20, 30]
      pld.includes?(vec3(1, 2, 3)).should be_true
      pld.includes?(vec3(-1, 2, 3)).should be_false

      pld = Chem::Spatial::Parallelepiped.new(vec3(1, 2, 3), {6, 3, 23})
      pld.includes?(vec3(3, 2.1, 20)).should be_true
      pld.includes?(vec3(2.4, 1.8, 23.1)).should be_false
    end

    it "tells if a vector is enclosed (non-orthogonal)" do
      pld = Chem::Spatial::Parallelepiped.new({23.803, 23.828, 5.387}, {90, 90, 120})
      pld.includes?(vec3(10, 20, 2)).should be_true
      pld.includes?(vec3(0, 0, 0)).should be_true
      pld.includes?(vec3(30, 30, 10)).should be_false
      pld.includes?(vec3(-3, 10, 2)).should be_true
      pld.includes?(vec3(-3, 2, 2)).should be_false
    end

    context "given a parallelepiped" do
      it "returns true when enclosed" do
        pld = Chem::Spatial::Parallelepiped.hexagonal(10, 10)
        pld.includes?(Chem::Spatial::Parallelepiped[5, 4, 6]).should be_true
        pld.includes?(Chem::Spatial::Parallelepiped.new(vec3(1, 2, 3), {5, 4, 6})).should be_true
      end

      it "returns false when intersected" do
        pld = Chem::Spatial::Parallelepiped.hexagonal(10, 10)
        pld.includes?(Chem::Spatial::Parallelepiped.new(vec3(-1, 2, -4.3), {5, 4, 6})).should be_false
      end

      it "returns false when out of bounds" do
        pld = Chem::Spatial::Parallelepiped.hexagonal(10, 10)
        pld.includes?(Chem::Spatial::Parallelepiped.new(vec3(-1, 2, -4.3), {5, 4, 6})).should be_false
      end
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      pld = Chem::Spatial::Parallelepiped.new vec3(1, 2, 3), vec3(4, 5, 6), vec3(7, 8, 9)
      pld.inspect.should eq "Chem::Spatial::Parallelepiped(@origin=[ 0 0 0 ], \
                             @basis=[[ 1  4  7 ], [ 2  5  8 ], [ 3  6  9 ]])"
    end
  end

  describe "#monoclinic?" do
    it "tells if the parallelepiped is monoclinic" do
      Chem::Spatial::Parallelepiped.cubic(1).monoclinic?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).monoclinic?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).monoclinic?.should be_true
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).monoclinic?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).monoclinic?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).monoclinic?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).monoclinic?.should be_false
    end
  end

  describe "#orthogonal?" do
    it "tells if the parallelepiped is orthogonal" do
      Chem::Spatial::Parallelepiped.cubic(1).orthogonal?.should be_true
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).orthogonal?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).orthogonal?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).orthogonal?.should be_true
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).orthogonal?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).orthogonal?.should be_true
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).orthogonal?.should be_false
    end
  end

  describe "#orthorhombic?" do
    it "tells if the parallelepiped is orthorhombic" do
      Chem::Spatial::Parallelepiped.cubic(1).orthorhombic?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).orthorhombic?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).orthorhombic?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).orthorhombic?.should be_true
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).orthorhombic?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).orthorhombic?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).orthorhombic?.should be_false
    end
  end

  describe "#pad" do
    context "given an orthogonal parallelepiped" do
      it "returns a padded parallelepiped" do
        pld = Chem::Spatial::Parallelepiped.cubic(10)
        pld = pld.pad(2)
        pld.size.should eq Chem::Spatial::Size3[14, 14, 14]
        pld.center.should eq pld.center
      end
    end

    context "given a non-orthogonal parallelepiped" do
      it "returns a padded parallelepiped" do
        pld = Chem::Spatial::Parallelepiped.new({4, 7, 8.5}, {90, 120, 90})
        pld = pld.pad(0.5)
        pld.size.should eq Chem::Spatial::Size3[5, 8, 9.5]
        pld.center.should be_close pld.center, 1e-15
      end
    end

    it "raises on negative padding" do
      expect_raises ArgumentError, "Negative padding" do
        Chem::Spatial::Parallelepiped.cubic(1).pad -5
      end
    end
  end

  describe "#rhombohedral?" do
    it "tells if the parallelepiped is rhombohedral" do
      Chem::Spatial::Parallelepiped.cubic(1).rhombohedral?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).rhombohedral?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).rhombohedral?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).rhombohedral?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).rhombohedral?.should be_true
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).rhombohedral?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).rhombohedral?.should be_false
    end
  end

  describe "#rotate" do
    it "returns a rotated parallelepiped" do
      pld = Chem::Spatial::Parallelepiped.hexagonal(2.3, 23.3)
      pld.rotate(vec3(1, 2, 3), 65).should eq \
        pld.transform(Chem::Spatial::AffineTransform.rotation(vec3(1, 2, 3), 65))
      pld.rotate(10, 6.4, 64.2).should eq \
        pld.transform(Chem::Spatial::AffineTransform.euler(10, 6.4, 64.2))
    end
  end

  describe "#size" do
    it "returns parallelepiped' size" do
      Chem::Spatial::Parallelepiped.hexagonal(5, 4).size.should be_close [5, 5, 4], 1e-15
      pld = Chem::Spatial::Parallelepiped.new vec3(1, 0, 0), vec3(2, 2, 0), vec3(0, 1, 1)
      pld.size.should be_close [1, Math.sqrt(8), Math.sqrt(2)], 1e-15
    end
  end

  describe "#tetragonal?" do
    it "tells if the parallelepiped is tetragonal" do
      Chem::Spatial::Parallelepiped.cubic(1).tetragonal?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).tetragonal?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).tetragonal?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).tetragonal?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).tetragonal?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).tetragonal?.should be_true
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).tetragonal?.should be_false
    end
  end

  describe "#transform" do
    it "returns a transformed parallelepiped" do
      transform = Chem::Spatial::AffineTransform.euler(45, 45, 68).translate(vec3(1, 2.5, -6.8))
      pld = Chem::Spatial::Parallelepiped.cubic(10).transform(transform)
      pld.center.should be_close vec3(5, 5, 5) + vec3(1, 2.5, -6.8), 1e-15
      pld.vertices.should eq [
        vec3(4.418121736513632, 6.778918885614988, -10.28396742013939),
        vec3(11.489189548379107, 1.7789188856149885, -5.283967420139391),
        vec3(-2.1380581731949375, 4.791868237596882, -2.999179522489622),
        vec3(4.933009638670538, -0.20813176240311737, 2.000820477510377),
        vec3(7.066990361329463, 15.208131762403116, -5.6008204775103785),
        vec3(14.138058173194938, 10.208131762403116, -0.6008204775103794),
        vec3(0.5108104516208938, 13.22108111438501, 1.68396742013939),
        vec3(7.581878263486369, 8.221081114385012, 6.683967420139389),
      ]
    end
  end

  describe "#translate" do
    it "translates the origin" do
      pld = Chem::Spatial::Parallelepiped.hexagonal(10, 10)
      pld = pld.translate(vec3(-5, 1, 20)).translate(vec3(1, 2, 10))
      pld.vmin.should eq [-4, 3, 30]
      pld.angles.should be_close({90, 90, 120}, 1e-3)
      pld.size.should be_close Chem::Spatial::Size3[10, 10, 10], 1e-12
    end
  end

  describe "#triclinic?" do
    it "tells if the parallelepiped is triclinic" do
      Chem::Spatial::Parallelepiped.cubic(1).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.hexagonal(1, 3).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.monoclinic(1, 3, 120).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.orthorhombic(1, 2, 3).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.rhombohedral(1, 120).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.tetragonal(1, 2).triclinic?.should be_false
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {85, 92, 132}).triclinic?.should be_true
    end
  end

  describe "#vertices" do
    it "returns parallelepiped' vertices" do
      pld = Chem::Spatial::Parallelepiped.new({10, 10, 10}, {90, 90, 120})
      vertices = pld.vertices
      vertices.size.should eq 8
      vertices.should be_close [
        vec3(0, 0, 0),
        vec3(0, 0, 10),
        vec3(-5, 8.660, 0),
        vec3(-5, 8.660, 10),
        vec3(10, 0, 0),
        vec3(10, 0, 10),
        vec3(5, 8.660, 0),
        vec3(5, 8.660, 10),
      ], 1e-3
    end
  end

  describe "#vmax" do
    context "given an orthogonal parallelepiped" do
      it "returns the maximum vertex" do
        Chem::Spatial::Parallelepiped[10, 5, 8].vmax.should eq [10, 5, 8]
      end
    end

    context "given a non-orthogonal parallelepiped" do
      it "returns the maximum vertex" do
        pld = Chem::Spatial::Parallelepiped.hexagonal(10, 12)
        pld = pld.translate(vec3(1.5, 3, -0.4))
        pld.vmax.should be_close [6.5, 11.66, 11.6], 1e-3
      end
    end
  end

  describe "#vmin" do
    context "given an orthogonal parallelepiped" do
      it "returns the minimum vertex (origin)" do
        Chem::Spatial::Parallelepiped[10, 5, 8].vmin.should eq [0, 0, 0]
      end
    end

    context "given a non-orthogonal parallelepiped" do
      it "returns the minimum vertex (origin)" do
        pld = Chem::Spatial::Parallelepiped.hexagonal(10, 12)
        pld = pld.translate(vec3(1.5, 3, -0.4))
        pld.vmin.should eq [1.5, 3, -0.4]
      end
    end
  end

  describe "#volume" do
    it "returns the volume enclosed by the parallelepiped" do
      Chem::Spatial::Parallelepiped[10, 20, 30].volume.should eq 6_000
      Chem::Spatial::Parallelepiped.hexagonal(5, 8).volume.should be_close 173.2050807569, 1e-10
      Chem::Spatial::Parallelepiped.hexagonal(10, 15).volume.should be_close 1299.038105676658, 1e-12
      Chem::Spatial::Parallelepiped.new({1, 2, 3}, {90, 101.2, 90}).volume.should be_close 5.8857309321, 1e-10
      Chem::Spatial::Parallelepiped.new(vec3(1, 2, 3), {6, 3, 23}).volume.should eq 414
    end
  end

  describe "#wrap" do
    it "wraps a vector" do
      pld = Chem::Spatial::Parallelepiped.new({15, 20, 9})

      pld.wrap(vec3(0, 0, 0)).should eq [0, 0, 0]
      pld.wrap(vec3(15, 20, 9)).should be_close [15, 20, 9], 1e-12
      pld.wrap(vec3(10, 10, 5)).should be_close [10, 10, 5], 1e-12
      pld.wrap(vec3(15.5, 21, -5)).should be_close [0.5, 1, 4], 1e-12
    end

    it "wraps a vector around a center" do
      pld = Chem::Spatial::Parallelepiped.new({32, 20, 19})
      center = vec3(32, 20, 19)

      [
        {[0, 0, 0], [32, 20, 19]},
        {[32, 20, 19], [32, 20, 19]},
        {[20.285, 14.688, 16.487], [20.285, 14.688, 16.487]},
        {[23.735, 19.25, 1.716], [23.735, 19.25, 20.716]},
      ].each do |(x, y, z), expected|
        pld.wrap(vec3(x, y, z), center).should be_close expected, 1e-12
      end
    end
  end

  describe "#xyz?" do
    it "returns true if aligned to XYZ" do
      Chem::Spatial::Parallelepiped[1, 2, 3].xyz?.should be_true
      Chem::Spatial::Parallelepiped.cubic(5).xyz?.should be_true
    end

    it "returns false if orthogonal but not aligned to XYZ" do
      # TODO: use Parallelepiped#rotate(23, 53, 10)
      transform = Chem::Spatial::AffineTransform.euler(23, 53, 10)
      basisvec = {vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1)}.map(&.transform(transform))
      Chem::Spatial::Parallelepiped.new(*basisvec).xyz?.should be_false
    end

    it "returns false if non-orthogonal" do
      Chem::Spatial::Parallelepiped.hexagonal(5, 10).xyz?.should be_false
    end
  end
end
