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

  describe "#bounds" do
    it "returns the bounds" do
      Lattice.new({1, 2, 3}).bounds.should eq Bounds[1, 2, 3]
      Lattice.new({5, 1, 5}, {90, 120, 90}).bounds.should eq Bounds.new(Size3[5, 1, 5], 90, 120, 90)
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.c = 4
      lattice.basis.should eq Mat3.diagonal(10, 20, 4)
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

  describe "#j=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.j = Vec3[1, 2, 3]
      lattice.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[1, 2, 3], Vec3[0, 0, 30])
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new({10, 20, 30})
      lattice.k = Vec3[1, 2, 3]
      lattice.basis.should eq Mat3.basis(Vec3[10, 0, 0], Vec3[0, 20, 0], Vec3[1, 2, 3])
    end
  end
end
