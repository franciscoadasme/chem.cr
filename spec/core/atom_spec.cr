require "../spec_helper"

describe Chem::Atom do
  describe "#within_covalent_distance?" do
    res = fake_structure.residues[0]

    it "returns true for covalently-bonded atoms" do
      res["N"].within_covalent_distance?(of: res["CA"]).should be_true
      res["CA"].within_covalent_distance?(of: res["C"]).should be_true
      res["CB"].within_covalent_distance?(of: res["CA"]).should be_true
    end

    it "returns false for non-bonded atoms" do
      res["N"].within_covalent_distance?(of: res["CB"]).should be_false
      res["CA"].within_covalent_distance?(of: res["O"]).should be_false
      res["CA"].within_covalent_distance?(of: res["OD1"]).should be_false
    end
  end
end
