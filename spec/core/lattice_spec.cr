require "../spec_helper"

describe Chem::Lattice do
  describe "#a=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.a = 20
      lattice.basis.should eq Basis.new(Size[20, 20, 30])
    end
  end

  describe "#b=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.b = 5
      lattice.basis.should eq Basis.new(Size[10, 5, 30])
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      Lattice.new(Size[1, 2, 3]).bounds.should eq Bounds[1, 2, 3]
      Lattice.new(Size[5, 1, 5], 90, 120, 90).bounds.should eq Bounds.new(Size[5, 1, 5], 90, 120, 90)
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.c = 4
      lattice.basis.should eq Basis.new(Size[10, 20, 4])
    end
  end

  describe "#i=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.i = Vec3[1, 2, 3]
      lattice.basis.should eq Basis.new(Vec3[1, 2, 3], Vec3[0, 20, 0], Vec3[0, 0, 30])
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      lattice = Chem::Lattice.new Vec3[1, 2, 3], Vec3[4, 5, 6], Vec3[7, 8, 9]
      lattice.inspect.should eq "<Lattice [1.0 2.0 3.0], [4.0 5.0 6.0], [7.0 8.0 9.0]>"
    end
  end

  describe "#j=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.j = Vec3[1, 2, 3]
      lattice.basis.should eq Basis.new(Vec3[10, 0, 0], Vec3[1, 2, 3], Vec3[0, 0, 30])
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(Size[10, 20, 30])
      lattice.k = Vec3[1, 2, 3]
      lattice.basis.should eq Basis.new(Vec3[10, 0, 0], Vec3[0, 20, 0], Vec3[1, 2, 3])
    end
  end
end
