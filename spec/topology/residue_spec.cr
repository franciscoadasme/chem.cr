require "../spec_helper"

describe Chem::Residue do
  system = fake_system include_bonds: true

  describe "#omega" do
    it "returns torsion angle omega" do
      system.residues[1].omega.should be_close -179.87, 1e-2
    end

    it "fails when residue is at the start" do
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        system.residues[0].omega
      end
    end
  end

  describe "#phi" do
    it "returns torsion angle phi" do
      system.residues[1].phi.should be_close -57.87, 1e-2
    end

    it "fails when residue is at the start" do
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        system.residues[0].phi
      end
    end
  end

  describe "#psi" do
    it "returns torsion angle psi" do
      system.residues[0].psi.should be_close 127.28, 1e-2
    end

    it "fails when residue is at the start" do
      expect_raises Chem::Error, "A:PHE2 is terminal" do
        system.residues[1].psi
      end
    end
  end
end
