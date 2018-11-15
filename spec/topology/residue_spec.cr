require "../spec_helper"

describe Chem::Residue do
  describe "#cis?" do
    it "returns true when residue is in the cis conformation" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[2].cis?.should be_true
    end

    it "returns true when residue is not in the cis conformation" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[1].cis?.should be_false
    end

    it "returns false when residue is at the start" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[0].cis?.should be_false
    end
  end

  describe "#hlxparam" do
    it "returns helical parameters" do
      st = Chem::PDB.read_first "spec/data/pdb/hlxparam.pdb"
      Chem::Topology.guess_topology of: st

      hlxparam = st.residues[1].hlxparam
      hlxparam.should_not be_nil
      zeta, theta, radius = hlxparam.not_nil!
      zeta.should be_close 1.63, 1e-2
      theta.should be_close 101.67, 1e-2
      radius.should be_close 2.24, 1e-2
    end

    it "returns nil when residue is terminal" do
      st = Chem::PDB.read_first "spec/data/pdb/hlxparam.pdb"
      Chem::Topology.guess_topology of: st

      st.residues.first.hlxparam.should be_nil
      st.residues.last.hlxparam.should be_nil
    end

    it "returns nil when residue is non-bonded to its previous/next residue" do
      st = Chem::PDB.read_first "spec/data/pdb/hlxparam.pdb"
      Chem::Topology.guess_topology of: st

      # there is a gap between residues 2 and 3
      st.residues[2].hlxparam.should be_nil
      st.residues[3].hlxparam.should be_nil
    end
  end

  describe "#omega" do
    it "returns torsion angle omega" do
      st = fake_structure include_bonds: true
      st.residues[1].omega.should be_close -179.87, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure include_bonds: true
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        st.residues[0].omega
      end
    end
  end

  describe "#omega?" do
    it "returns torsion angle omega" do
      st = fake_structure include_bonds: true
      st.residues[1].omega?.should_not be_nil
      st.residues[1].omega?.not_nil!.should be_close -179.87, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure include_bonds: true
      st.residues[0].omega?.should be_nil
    end
  end

  describe "#phi" do
    it "returns torsion angle phi" do
      st = fake_structure include_bonds: true
      st.residues[1].phi.should be_close -57.87, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure include_bonds: true
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        st.residues[0].phi
      end
    end
  end

  describe "#phi?" do
    it "returns torsion angle phi" do
      st = fake_structure include_bonds: true
      st.residues[1].phi?.should_not be_nil
      st.residues[1].phi?.not_nil!.should be_close -57.87, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure include_bonds: true
      st.residues[0].phi?.should be_nil
    end
  end

  describe "#psi" do
    it "returns torsion angle psi" do
      st = fake_structure include_bonds: true
      st.residues[0].psi.should be_close 127.28, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure include_bonds: true
      expect_raises Chem::Error, "A:PHE2 is terminal" do
        st.residues[1].psi
      end
    end
  end

  describe "#psi?" do
    it "returns torsion angle psi" do
      st = fake_structure include_bonds: true
      st.residues[0].psi?.should_not be_nil
      st.residues[0].psi?.not_nil!.should be_close 127.28, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure include_bonds: true
      st.residues[1].psi?.should be_nil
    end
  end

  describe "#trans?" do
    it "returns true when residue is in the trans conformation" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[1].trans?.should be_true
    end

    it "returns true when residue is not in the trans conformation" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[2].trans?.should be_false
    end

    it "returns false when residue is at the start" do
      st = PDB.read_first "spec/data/pdb/cis-trans.pdb"
      Chem::Topology.guess_topology of: st
      st.residues[0].trans?.should be_false
    end
  end
end
