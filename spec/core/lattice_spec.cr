require "../spec_helper"

describe Chem::Lattice do
  describe ".cubic" do
    it "returns a cubic lattice" do
      lattice = Lattice.cubic(10.1)
      lattice.size.should eq Size3[10.1, 10.1, 10.1]
      lattice.angles.should eq({90, 90, 90})
    end
  end

  describe ".hexagonal" do
    it "returns a hexagonal lattice" do
      lattice = Lattice.hexagonal(1, 2)
      lattice.size.should be_close Size3[1, 1, 2], 1e-15
      lattice.angles.should be_close({90, 90, 120}, 1e-8)
    end
  end

  describe ".monoclinic" do
    it "returns a monoclinic lattice" do
      lattice = Lattice.monoclinic(1, 2, 45)
      lattice.size.should eq Size3[1, 1, 2]
      lattice.angles.should eq({90, 45, 90})
    end
  end

  describe ".orthorhombic" do
    it "returns a orthorhombic lattice" do
      lattice = Lattice.orthorhombic(1, 2, 3)
      lattice.size.should eq Size3[1, 2, 3]
      lattice.angles.should eq({90, 90, 90})
    end
  end

  describe ".rhombohedral" do
    it "returns a rhombohedral lattice" do
      lattice = Lattice.rhombohedral(1, 45)
      lattice.size.should eq Size3[1, 1, 1]
      lattice.angles.should eq({45, 45, 45})
    end
  end

  describe ".tetragonal" do
    it "returns a tetragonal lattice" do
      lattice = Lattice.tetragonal(1, 2)
      lattice.size.should eq Size3[1, 1, 2]
      lattice.angles.should eq({90, 90, 90})
    end
  end

  describe ".new" do
    it "creates a lattice with vectors" do
      lattice = Lattice.new Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 0, 1]
      lattice.i.should eq Vec3[1, 0, 0]
      lattice.j.should eq Vec3[0, 1, 0]
      lattice.k.should eq Vec3[0, 0, 1]
    end

    it "creates a lattice with size" do
      lattice = Lattice.new({74.23, 135.35, 148.46})
      lattice.i.should be_close Vec3[74.23, 0, 0], 1e-6
      lattice.j.should be_close Vec3[0, 135.35, 0], 1e-6
      lattice.k.should be_close Vec3[0, 0, 148.46], 1e-6
    end

    it "creates a lattice with size and angles" do
      lattice = Lattice.new({8.661, 11.594, 21.552}, {86.389999, 82.209999, 76.349998})
      lattice.i.should be_close Vec3[8.661, 0.0, 0.0], 1e-6
      lattice.j.should be_close Vec3[2.736071, 11.266532, 0.0], 1e-6
      lattice.k.should be_close Vec3[2.921216, 0.687043, 21.342052], 1e-6
    end
  end

  describe "#a" do
    it "return the size of the first vector" do
      Lattice.new({8.661, 11.594, 21.552}).a.should eq 8.661
      Lattice.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).a.should eq 8.661
    end
  end

  describe "#alpha" do
    it "returns alpha" do
      Lattice.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).alpha.should eq 45
    end
  end

  describe "#angles" do
    it "returns unit cell angles" do
      lattice = Lattice.new({1, 2, 3}, {45, 120, 89})
      lattice.angles.should be_close({45, 120, 89}, 1e-8)
    end
  end

  describe "#a=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.a = 20
      lattice.basis.should eq Mat3.diagonal(20, 20, 30)
    end
  end

  describe "#b=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.b = 5
      lattice.basis.should eq Mat3.diagonal(10, 5, 30)
    end
  end

  describe "#b" do
    it "return the size of the second vector" do
      Lattice.new({8.661, 11.594, 21.552}).b.should eq 11.594
      Lattice.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).b.should eq 11.594
    end
  end

  describe "#beta" do
    it "returns beta" do
      Lattice.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).beta.should eq 90
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      Lattice.new({1, 2, 3}).bounds.should eq Bounds[1, 2, 3]

      lattice = Lattice.new({5, 1, 5}, {90, 120, 90})
      bounds = lattice.bounds
      bounds.origin.should eq Vec3.zero
      bounds.basis.should eq lattice.basis
    end
  end

  describe "#c" do
    it "return the size of the third vector" do
      Lattice.new({8.661, 11.594, 21.552}).c.should eq 21.552
      Lattice.new({8.661, 11.594, 21.552}, {86.39, 82.201, 76.345}).c.should be_close 21.552, 1e-8
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.c = 4
      lattice.basis.should eq Mat3.diagonal(10, 20, 4)
    end
  end

  describe "#cart" do
    it "returns Cartesian coordinates" do
      lattice = Lattice.new({20, 20, 16})
      lattice.cart(Vec3[0.5, 0.65, 1]).should be_close Vec3[10, 13, 16], 1e-15
      lattice.cart(Vec3[1.5, 0.23, 0.9]).should be_close Vec3[30, 4.6, 14.4], 1e-15

      lattice = Lattice.new({20, 10, 16})
      lattice.cart(Vec3[0.5, 0.65, 1]).should be_close Vec3[10, 6.5, 16], 1e-15

      lattice = Lattice.new(
        Vec3[8.497, 0.007, 0.031],
        Vec3[10.148, 42.359, 0.503],
        Vec3[7.296, 2.286, 53.093])
      lattice.cart(Vec3[0.724, 0.04, 0.209]).should be_close Vec3[8.083, 2.177, 11.139], 1e-3
    end
  end

  describe "#cubic?" do
    it "tells if lattice is cubic" do
      Lattice.cubic(1).cubic?.should be_true
      Lattice.hexagonal(1, 3).cubic?.should be_false
      Lattice.monoclinic(1, 3, 120).cubic?.should be_false
      Lattice.orthorhombic(1, 2, 3).cubic?.should be_false
      Lattice.rhombohedral(1, 120).cubic?.should be_false
      Lattice.tetragonal(1, 2).cubic?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).cubic?.should be_false
    end
  end

  describe "#fract" do
    it "returns fractional coordinates" do
      lattice = Lattice.new({10, 20, 30})
      lattice.fract(Vec3.zero).should eq Vec3.zero
      lattice.fract(Vec3[1, 2, 3]).should be_close Vec3[0.1, 0.1, 0.1], 1e-15
      lattice.fract(Vec3[2, 3, 15]).should be_close Vec3[0.2, 0.15, 0.5], 1e-15

      lattice = Lattice.new({20, 20, 30})
      lattice.fract(Vec3[1, 2, 3]).should be_close Vec3[0.05, 0.1, 0.1], 1e-15
    end
  end

  describe "#gamma" do
    it "returns gamma" do
      Lattice.new(Vec3[1, 0, 0], Vec3[0, 1, 0], Vec3[0, 1, 1]).gamma.should eq 90
    end
  end

  describe "#hexagonal?" do
    it "tells if lattice is hexagonal" do
      Lattice.cubic(1).hexagonal?.should be_false
      Lattice.hexagonal(1, 3).hexagonal?.should be_true
      Lattice.monoclinic(1, 3, 120).hexagonal?.should be_false
      Lattice.orthorhombic(1, 2, 3).hexagonal?.should be_false
      Lattice.rhombohedral(1, 120).hexagonal?.should be_false
      Lattice.tetragonal(1, 2).hexagonal?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).hexagonal?.should be_false
    end
  end

  describe "#i" do
    it "returns the first unit cell vector" do
      lattice = Lattice.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      lattice.i.should eq Vec3[1, 2, 3]
    end
  end

  describe "#i=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.i = Vec3[1, 2, 3]
      lattice.basis.should eq Mat3.basis(Vec3[1, 2, 3], Vec3[0, 20, 0], Vec3[0, 0, 30])
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      lattice = Chem::Lattice.new Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9]
      lattice.inspect.should eq "<Lattice Vec3[ 1  2  3 ], Vec3[ 4  5  6 ], Vec3[ 7  8  9 ]>"
    end
  end

  describe "#j" do
    it "returns the second unit cell vector" do
      lattice = Lattice.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      lattice.j.should eq Vec3[4, 5, 6]
    end
  end

  describe "#j=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.j = Vec3[1, 2, 3]
      lattice.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[1, 2, 3], Vec3[0, 0, 30])
    end
  end

  describe "#k" do
    it "returns the third unit cell vector" do
      lattice = Lattice.new(Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9])
      lattice.k.should eq Vec3[7, 8, 9]
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.k = Vec3[1, 2, 3]
      lattice.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[0, 20, 0], Vec3[1, 2, 3])
    end
  end

  describe "#monoclinic?" do
    it "tells if lattice is monoclinic" do
      Lattice.cubic(1).monoclinic?.should be_false
      Lattice.hexagonal(1, 3).monoclinic?.should be_false
      Lattice.monoclinic(1, 3, 120).monoclinic?.should be_true
      Lattice.orthorhombic(1, 2, 3).monoclinic?.should be_false
      Lattice.rhombohedral(1, 120).monoclinic?.should be_false
      Lattice.tetragonal(1, 2).monoclinic?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).monoclinic?.should be_false
    end
  end

  describe "#orthogonal?" do
    it "tells if lattice is orthogonal" do
      Lattice.cubic(1).orthogonal?.should be_true
      Lattice.hexagonal(1, 3).orthogonal?.should be_false
      Lattice.monoclinic(1, 3, 120).orthogonal?.should be_false
      Lattice.orthorhombic(1, 2, 3).orthogonal?.should be_true
      Lattice.rhombohedral(1, 120).orthogonal?.should be_false
      Lattice.tetragonal(1, 2).orthogonal?.should be_true
      Lattice.new({1, 2, 3}, {85, 92, 132}).orthogonal?.should be_false
    end
  end

  describe "#orthorhombic?" do
    it "tells if lattice is orthorhombic" do
      Lattice.cubic(1).orthorhombic?.should be_false
      Lattice.hexagonal(1, 3).orthorhombic?.should be_false
      Lattice.monoclinic(1, 3, 120).orthorhombic?.should be_false
      Lattice.orthorhombic(1, 2, 3).orthorhombic?.should be_true
      Lattice.rhombohedral(1, 120).orthorhombic?.should be_false
      Lattice.tetragonal(1, 2).orthorhombic?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).orthorhombic?.should be_false
    end
  end

  describe "#rhombohedral?" do
    it "tells if lattice is rhombohedral" do
      Lattice.cubic(1).rhombohedral?.should be_false
      Lattice.hexagonal(1, 3).rhombohedral?.should be_false
      Lattice.monoclinic(1, 3, 120).rhombohedral?.should be_false
      Lattice.orthorhombic(1, 2, 3).rhombohedral?.should be_false
      Lattice.rhombohedral(1, 120).rhombohedral?.should be_true
      Lattice.tetragonal(1, 2).rhombohedral?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).rhombohedral?.should be_false
    end
  end

  describe "#size" do
    it "returns lattice' size" do
      Lattice.hexagonal(5, 4).size.should be_close Size3[5, 5, 4], 1e-15
      lattice = Lattice.new Vec3[1, 0, 0], Vec3[2, 2, 0], Vec3[0, 1, 1]
      lattice.size.should be_close Size3[1, Math.sqrt(8), Math.sqrt(2)], 1e-15
    end
  end

  describe "#tetragonal?" do
    it "tells if lattice is tetragonal" do
      Lattice.cubic(1).tetragonal?.should be_false
      Lattice.hexagonal(1, 3).tetragonal?.should be_false
      Lattice.monoclinic(1, 3, 120).tetragonal?.should be_false
      Lattice.orthorhombic(1, 2, 3).tetragonal?.should be_false
      Lattice.rhombohedral(1, 120).tetragonal?.should be_false
      Lattice.tetragonal(1, 2).tetragonal?.should be_true
      Lattice.new({1, 2, 3}, {85, 92, 132}).tetragonal?.should be_false
    end
  end

  describe "#triclinic?" do
    it "tells if lattice is triclinic" do
      Lattice.cubic(1).triclinic?.should be_false
      Lattice.hexagonal(1, 3).triclinic?.should be_false
      Lattice.monoclinic(1, 3, 120).triclinic?.should be_false
      Lattice.orthorhombic(1, 2, 3).triclinic?.should be_false
      Lattice.rhombohedral(1, 120).triclinic?.should be_false
      Lattice.tetragonal(1, 2).triclinic?.should be_false
      Lattice.new({1, 2, 3}, {85, 92, 132}).triclinic?.should be_true
    end
  end
end
