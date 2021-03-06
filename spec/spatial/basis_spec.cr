require "../spec_helper"

describe Chem::Spatial::Basis do
  describe ".new" do
    it "creates a basis with vectors" do
      basis = Basis.new V[1, 0, 0], V[0, 1, 0], V[0, 0, 1]
      basis.i.should eq V[1, 0, 0]
      basis.j.should eq V[0, 1, 0]
      basis.k.should eq V[0, 0, 1]
    end

    it "creates a basis with size" do
      basis = Basis.new S[74.23, 135.35, 148.46]
      basis.i.should be_close V[74.23, 0, 0], 1e-6
      basis.j.should be_close V[0, 135.35, 0], 1e-6
      basis.k.should be_close V[0, 0, 148.46], 1e-6
    end

    it "creates a basis with size and angles" do
      basis = Basis.new S[8.661, 11.594, 21.552], 86.389999, 82.209999, 76.349998
      basis.i.should be_close V[8.661, 0.0, 0.0], 1e-6
      basis.j.should be_close V[2.736071, 11.266532, 0.0], 1e-6
      basis.k.should be_close V[2.921216, 0.687043, 21.342052], 1e-6
    end
  end

  describe "#==" do
    it "tells if two basis are equal" do
      b1 = Basis.new S[8.661, 11.594, 21.552], 86.389999, 82.209999, 76.349998
      b1.should eq b1
      b1.transform # triggers internal caching
      b1.should eq Basis.new(S[8.661, 11.594, 21.552], 86.389999, 82.209999, 76.349998)
      b1.should_not eq Basis.new(S[8.661, 11.594, 21.552])
    end
  end

  describe "#a" do
    it "return the size of the first vector" do
      Basis.new(S[8.661, 11.594, 21.552]).a.should eq 8.661
      Basis.new(S[8.661, 11.594, 21.552], 86.39, 82.201, 76.345).a.should eq 8.661
    end
  end

  describe "#alpha" do
    it "returns alpha" do
      Basis.new(V[1, 0, 0], V[0, 1, 0], V[0, 1, 1]).alpha.should eq 45
    end
  end

  describe "#b" do
    it "return the size of the second vector" do
      Basis.new(S[8.661, 11.594, 21.552]).b.should eq 11.594
      Basis.new(S[8.661, 11.594, 21.552], 86.39, 82.201, 76.345).b.should eq 11.594
    end
  end

  describe "#beta" do
    it "returns beta" do
      Basis.new(V[1, 0, 0], V[0, 1, 0], V[0, 1, 1]).beta.should eq 90
    end
  end

  describe "#c" do
    it "return the size of the third vector" do
      Basis.new(S[8.661, 11.594, 21.552]).c.should eq 21.552
      Basis.new(S[8.661, 11.594, 21.552], 86.39, 82.201, 76.345).c.should be_close 21.552, 1e-8
    end
  end

  describe "#gamma" do
    it "returns gamma" do
      Basis.new(V[1, 0, 0], V[0, 1, 0], V[0, 1, 1]).gamma.should eq 90
    end
  end

  describe "#size" do
    it "returns basis' size" do
      Basis.new(S[5, 5, 4], 90, 90, 120).size.should be_close S[5, 5, 4], 1e-15
      basis = Basis.new V[1, 0, 0], V[2, 2, 0], V[0, 1, 1]
      basis.size.should be_close S[1, Math.sqrt(8), Math.sqrt(2)], 1e-15
    end
  end
end
