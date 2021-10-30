require "../spec_helper"

describe Chem::UnitCell do
  describe ".cubic" do
    it "returns a cubic cell" do
      cell = UnitCell.cubic(10.1)
      cell.size.should eq Size3[10.1, 10.1, 10.1]
      cell.angles.should eq({90, 90, 90})
    end
  end

  describe ".hexagonal" do
    it "returns a hexagonal cell" do
      cell = UnitCell.hexagonal(1, 2)
      cell.size.should be_close Size3[1, 1, 2], 1e-15
      cell.angles.should be_close({90, 90, 120}, 1e-8)
    end
  end

  describe ".monoclinic" do
    it "returns a monoclinic cell" do
      cell = UnitCell.monoclinic(1, 2, 45)
      cell.size.should eq Size3[1, 1, 2]
      cell.angles.should eq({90, 45, 90})
    end
  end

  describe ".orthorhombic" do
    it "returns a orthorhombic cell" do
      cell = UnitCell.orthorhombic(1, 2, 3)
      cell.size.should eq Size3[1, 2, 3]
      cell.angles.should eq({90, 90, 90})
    end
  end

  describe ".rhombohedral" do
    it "returns a rhombohedral cell" do
      cell = UnitCell.rhombohedral(1, 45)
      cell.size.should eq Size3[1, 1, 1]
      cell.angles.should eq({45, 45, 45})
    end
  end

  describe ".tetragonal" do
    it "returns a tetragonal cell" do
      cell = UnitCell.tetragonal(1, 2)
      cell.size.should eq Size3[1, 1, 2]
      cell.angles.should eq({90, 90, 90})
    end
  end

  describe ".new" do
    it "creates a cell with vectors" do
      cell = UnitCell.new Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 0, 1]
      cell.i.should eq Vec3[1, 0, 0]
      cell.j.should eq Vec3[0, 1, 0]
      cell.k.should eq Vec3[0, 0, 1]
    end

    it "creates a cell with size" do
      cell = UnitCell.new({74.23, 135.35, 148.46})
      cell.i.should be_close Vec3[74.23, 0, 0], 1e-6
      cell.j.should be_close Vec3[0, 135.35, 0], 1e-6
      cell.k.should be_close Vec3[0, 0, 148.46], 1e-6
    end

    it "creates a cell with size and angles" do
      cell = UnitCell.new({8.661, 11.594, 21.552}, {86.389999, 82.209999, 76.349998})
      cell.i.should be_close Vec3[8.661, 0.0, 0.0], 1e-6
      cell.j.should be_close Vec3[2.736071, 11.266532, 0.0], 1e-6
      cell.k.should be_close Vec3[2.921216, 0.687043, 21.342052], 1e-6
    end
  end

  describe "#a" do
    it "return the size of the first vector" do
      UnitCell.new({8.661, 11.594, 21.552}).a.should eq 8.661
      UnitCell.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).a.should eq 8.661
    end
  end

  describe "#alpha" do
    it "returns alpha" do
      UnitCell.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).alpha.should eq 45
    end
  end

  describe "#angles" do
    it "returns unit cell angles" do
      cell = UnitCell.new({1, 2, 3}, {45, 120, 89})
      cell.angles.should be_close({45, 120, 89}, 1e-8)
    end
  end

  describe "#a=" do
    it "sets the size of the first basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.a = 20
      cell.basis.should eq Mat3.diagonal(20, 20, 30)
    end
  end

  describe "#b=" do
    it "sets the size of the second basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.b = 5
      cell.basis.should eq Mat3.diagonal(10, 5, 30)
    end
  end

  describe "#b" do
    it "return the size of the second vector" do
      UnitCell.new({8.661, 11.594, 21.552}).b.should eq 11.594
      UnitCell.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).b.should eq 11.594
    end
  end

  describe "#beta" do
    it "returns beta" do
      UnitCell.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).beta.should eq 90
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      UnitCell.new({1, 2, 3}).bounds.should eq Bounds[1, 2, 3]

      cell = UnitCell.new({5, 1, 5}, {90, 120, 90})
      bounds = cell.bounds
      bounds.origin.should eq Vec3.zero
      bounds.basis.should eq cell.basis
    end
  end

  describe "#c" do
    it "return the size of the third vector" do
      UnitCell.new({8.661, 11.594, 21.552}).c.should eq 21.552
      UnitCell.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).c.should be_close 21.552, 1e-8
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.c = 4
      cell.basis.should eq Mat3.diagonal(10, 20, 4)
    end
  end

  describe "#cart" do
    it "returns Cartesian coordinates" do
      cell = UnitCell.new({20, 20, 16})
      cell.cart(Vec3[0.5, 0.65, 1]).should be_close Vec3[10, 13, 16], 1e-15
      cell.cart(Vec3[1.5, 0.23, 0.9]).should be_close Vec3[30, 4.6, 14.4], 1e-15

      cell = UnitCell.new({20, 10, 16})
      cell.cart(Vec3[0.5, 0.65, 1]).should be_close Vec3[10, 6.5, 16], 1e-15

      cell = UnitCell.new(
        Vec3[8.497, 0.007, 0.031],
        Vec3[10.148, 42.359, 0.503],
        Vec3[7.296, 2.286, 53.093])
      cell.cart(Vec3[0.724, 0.04, 0.209]).should be_close Vec3[8.083, 2.177, 11.139], 1e-3
    end
  end

  describe "#cubic?" do
    it "tells if cell is cubic" do
      UnitCell.cubic(1).cubic?.should be_true
      UnitCell.hexagonal(1, 3).cubic?.should be_false
      UnitCell.monoclinic(1, 3, 120).cubic?.should be_false
      UnitCell.orthorhombic(1, 2, 3).cubic?.should be_false
      UnitCell.rhombohedral(1, 120).cubic?.should be_false
      UnitCell.tetragonal(1, 2).cubic?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).cubic?.should be_false
    end
  end

  describe "#fract" do
    it "returns fractional coordinates" do
      cell = UnitCell.new({10, 20, 30})
      cell.fract(Vec3.zero).should eq Vec3.zero
      cell.fract(Vec3[1, 2, 3]).should be_close Vec3[0.1, 0.1, 0.1], 1e-15
      cell.fract(Vec3[2, 3, 15]).should be_close Vec3[0.2, 0.15, 0.5], 1e-15

      cell = UnitCell.new({20, 20, 30})
      cell.fract(Vec3[1, 2, 3]).should be_close Vec3[0.05, 0.1, 0.1], 1e-15
    end
  end

  describe "#gamma" do
    it "returns gamma" do
      UnitCell.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).gamma.should eq 90
    end
  end

  describe "#hexagonal?" do
    it "tells if cell is hexagonal" do
      UnitCell.cubic(1).hexagonal?.should be_false
      UnitCell.hexagonal(1, 3).hexagonal?.should be_true
      UnitCell.monoclinic(1, 3, 120).hexagonal?.should be_false
      UnitCell.orthorhombic(1, 2, 3).hexagonal?.should be_false
      UnitCell.rhombohedral(1, 120).hexagonal?.should be_false
      UnitCell.tetragonal(1, 2).hexagonal?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).hexagonal?.should be_false
    end
  end

  describe "#i" do
    it "returns the first unit cell vector" do
      cell = UnitCell.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      cell.i.should eq Vec3[1, 2, 3]
    end
  end

  describe "#i=" do
    it "sets the size of the first basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.i = Vec3[1, 2, 3]
      cell.basis.should eq Mat3.basis(Vec3[1, 2, 3], Vec3[0, 20, 0], Vec3[0, 0, 30])
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      cell = UnitCell.new Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9]
      cell.inspect.should eq "<UnitCell Vec3[ 1  2  3 ], Vec3[ 4  5  6 ], Vec3[ 7  8  9 ]>"
    end
  end

  describe "#j" do
    it "returns the second unit cell vector" do
      cell = UnitCell.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      cell.j.should eq Vec3[4, 5, 6]
    end
  end

  describe "#j=" do
    it "sets the size of the second basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.j = Vec3[1, 2, 3]
      cell.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[1, 2, 3], Vec3[0, 0, 30])
    end
  end

  describe "#k" do
    it "returns the third unit cell vector" do
      cell = UnitCell.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      cell.k.should eq Vec3[7, 8, 9]
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      cell = UnitCell.new({10, 20, 30})
      cell.k = Vec3[1, 2, 3]
      cell.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[0, 20, 0], Vec3[1, 2, 3])
    end
  end

  describe "#monoclinic?" do
    it "tells if cell is monoclinic" do
      UnitCell.cubic(1).monoclinic?.should be_false
      UnitCell.hexagonal(1, 3).monoclinic?.should be_false
      UnitCell.monoclinic(1, 3, 120).monoclinic?.should be_true
      UnitCell.orthorhombic(1, 2, 3).monoclinic?.should be_false
      UnitCell.rhombohedral(1, 120).monoclinic?.should be_false
      UnitCell.tetragonal(1, 2).monoclinic?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).monoclinic?.should be_false
    end
  end

  describe "#orthogonal?" do
    it "tells if cell is orthogonal" do
      UnitCell.cubic(1).orthogonal?.should be_true
      UnitCell.hexagonal(1, 3).orthogonal?.should be_false
      UnitCell.monoclinic(1, 3, 120).orthogonal?.should be_false
      UnitCell.orthorhombic(1, 2, 3).orthogonal?.should be_true
      UnitCell.rhombohedral(1, 120).orthogonal?.should be_false
      UnitCell.tetragonal(1, 2).orthogonal?.should be_true
      UnitCell.new({1, 2, 3}, {85, 92, 132}).orthogonal?.should be_false
    end
  end

  describe "#orthorhombic?" do
    it "tells if cell is orthorhombic" do
      UnitCell.cubic(1).orthorhombic?.should be_false
      UnitCell.hexagonal(1, 3).orthorhombic?.should be_false
      UnitCell.monoclinic(1, 3, 120).orthorhombic?.should be_false
      UnitCell.orthorhombic(1, 2, 3).orthorhombic?.should be_true
      UnitCell.rhombohedral(1, 120).orthorhombic?.should be_false
      UnitCell.tetragonal(1, 2).orthorhombic?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).orthorhombic?.should be_false
    end
  end

  describe "#rhombohedral?" do
    it "tells if cell is rhombohedral" do
      UnitCell.cubic(1).rhombohedral?.should be_false
      UnitCell.hexagonal(1, 3).rhombohedral?.should be_false
      UnitCell.monoclinic(1, 3, 120).rhombohedral?.should be_false
      UnitCell.orthorhombic(1, 2, 3).rhombohedral?.should be_false
      UnitCell.rhombohedral(1, 120).rhombohedral?.should be_true
      UnitCell.tetragonal(1, 2).rhombohedral?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).rhombohedral?.should be_false
    end
  end

  describe "#size" do
    it "returns cell' size" do
      UnitCell.hexagonal(5, 4).size.should be_close Size3[5, 5, 4], 1e-15
      cell = UnitCell.new Vec3[1, 0, 0], Vec3[2, 2, 0], Vec3[0, 1, 1]
      cell.size.should be_close Size3[1, Math.sqrt(8), Math.sqrt(2)], 1e-15
    end
  end

  describe "#tetragonal?" do
    it "tells if cell is tetragonal" do
      UnitCell.cubic(1).tetragonal?.should be_false
      UnitCell.hexagonal(1, 3).tetragonal?.should be_false
      UnitCell.monoclinic(1, 3, 120).tetragonal?.should be_false
      UnitCell.orthorhombic(1, 2, 3).tetragonal?.should be_false
      UnitCell.rhombohedral(1, 120).tetragonal?.should be_false
      UnitCell.tetragonal(1, 2).tetragonal?.should be_true
      UnitCell.new({1, 2, 3}, {85, 92, 132}).tetragonal?.should be_false
    end
  end

  describe "#triclinic?" do
    it "tells if cell is triclinic" do
      UnitCell.cubic(1).triclinic?.should be_false
      UnitCell.hexagonal(1, 3).triclinic?.should be_false
      UnitCell.monoclinic(1, 3, 120).triclinic?.should be_false
      UnitCell.orthorhombic(1, 2, 3).triclinic?.should be_false
      UnitCell.rhombohedral(1, 120).triclinic?.should be_false
      UnitCell.tetragonal(1, 2).triclinic?.should be_false
      UnitCell.new({1, 2, 3}, {85, 92, 132}).triclinic?.should be_true
    end
  end

  describe "#volume" do
    it "returns the cell volume" do
      cell = UnitCell.hexagonal(10, 15)
      cell.volume.should be_close 1299.038105676658, 1e-12
    end
  end

  describe "#wrap" do
    it "wraps a vector" do
      cell = UnitCell.new({15, 20, 9})

      cell.wrap(Vec3[0, 0, 0]).should eq Vec3[0, 0, 0]
      cell.wrap(Vec3[15, 20, 9]).should be_close Vec3[15, 20, 9], 1e-12
      cell.wrap(Vec3[10, 10, 5]).should be_close Vec3[10, 10, 5], 1e-12
      cell.wrap(Vec3[15.5, 21, -5]).should be_close Vec3[0.5, 1, 4], 1e-12
    end

    it "wraps a vector around a center" do
      cell = UnitCell.new({32, 20, 19})
      center = Vec3[32, 20, 19]

      [
        {Vec3[0, 0, 0], Vec3[32, 20, 19]},
        {Vec3[32, 20, 19], Vec3[32, 20, 19]},
        {Vec3[20.285, 14.688, 16.487], Vec3[20.285, 14.688, 16.487]},
        {Vec3[23.735, 19.25, 1.716], Vec3[23.735, 19.25, 20.716]},
      ].each do |vec, expected|
        cell.wrap(vec, center).should be_close expected, 1e-12
      end
    end
  end
end
