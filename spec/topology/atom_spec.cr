require "../spec_helper"

describe Chem::Atom do
  describe "#within_covalent_distance?" do
    atoms = fake_system.residues[0].atoms

    it "returns true for covalently-bonded atoms" do
      atoms["N"].within_covalent_distance?(of: atoms["CA"]).should be_true
      atoms["CA"].within_covalent_distance?(of: atoms["C"]).should be_true
      atoms["CB"].within_covalent_distance?(of: atoms["CA"]).should be_true
    end

    it "returns false for non-bonded atoms" do
      atoms["N"].within_covalent_distance?(of: atoms["CB"]).should be_false
      atoms["CA"].within_covalent_distance?(of: atoms["O"]).should be_false
      atoms["CA"].within_covalent_distance?(of: atoms["OD1"]).should be_false
    end
  end
end
