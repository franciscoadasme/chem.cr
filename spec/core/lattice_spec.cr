require "../spec_helper"

describe Chem::Lattice do
  describe "#a=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.a = 20
      lattice.basis.should eq Basis.new(S[20, 20, 30])
    end
  end

  describe "#b=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.b = 5
      lattice.basis.should eq Basis.new(S[10, 5, 30])
    end
  end

  describe "#bounds" do
    it "returns the bounds" do
      Lattice.new(S[1, 2, 3]).bounds.should eq Bounds[1, 2, 3]
      Lattice.new(S[5, 1, 5], 90, 120, 90).bounds.should eq Bounds.new(S[5, 1, 5], 90, 120, 90)
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.c = 4
      lattice.basis.should eq Basis.new(S[10, 20, 4])
    end
  end

  describe "#i=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.i = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[1, 2, 3], V[0, 20, 0], V[0, 0, 30])
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      lattice = Chem::Lattice.new V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]
      lattice.inspect.should eq "<Lattice [1.0 2.0 3.0], [4.0 5.0 6.0], [7.0 8.0 9.0]>"
    end
  end

  describe "#j=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.j = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[10, 0, 0], V[1, 2, 3], V[0, 0, 30])
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.k = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[10, 0, 0], V[0, 20, 0], V[1, 2, 3])
    end
  end
end
