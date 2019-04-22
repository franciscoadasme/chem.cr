require "../spec_helper"

alias Basis = Chem::Linalg::Basis

describe Chem::Linalg::Basis do
  describe ".standard" do
    it "returns the standard basis" do
      Basis.standard.should eq Basis.new(V.x, V.y, V.z)
    end
  end

  describe "#standard?" do
    it "returns true when basis is standard" do
      Basis.standard.standard?.should be_true
    end

    it "returns false when basis is not standard" do
      Basis.new(V[1, 1, 0], V[2, 0, 0], V[0.4, 1, 0]).standard?.should be_false
    end
  end
end
