require "../spec_helper"

describe Chem::Residue do
  describe ".new" do
    it "sets kind from templates" do
      structure = Chem::Structure.new
      chain = Chem::Chain.new 'A', structure
      Chem::Residue.new("TYR", 1, chain).kind.protein?.should be_true
      Chem::Residue.new("HOH", 2, chain).kind.solvent?.should be_true
      Chem::Residue.new("ULK", 2, chain).kind.other?.should be_true
    end
  end

  describe "#bonded?" do
    it "tells if two residues are bonded through any pair of atoms" do
      structure = fake_structure include_bonds: true
      structure.dig('A', 1).bonded?(structure.dig('A', 2)).should be_true
      structure.dig('A', 1).bonded?(structure.dig('B', 1)).should be_false
    end

    it "tells if two residues are bonded through a specific pair of atoms" do
      structure = fake_structure include_bonds: true
      structure.dig('A', 1).bonded?(structure.dig('A', 2), "C", "N").should be_true
      structure.dig('A', 1).bonded?(structure.dig('A', 2), "CB", "CA").should be_false
      structure.dig('A', 1).bonded?(structure.dig('B', 1), "C", "N").should be_false
      structure.dig('A', 2).bonded?(structure.dig('A', 1), "C", "N").should be_false
    end

    it "tells if two residues are bonded through a specific bond type" do
      bond_t = Chem::Topology::BondType.new "C", "N"
      structure = fake_structure include_bonds: true
      structure.dig('A', 1).bonded?(structure.dig('A', 2), bond_t).should be_true
      structure.dig('A', 2).bonded?(structure.dig('A', 1), bond_t).should be_false
      structure.dig('A', 1).bonded?(structure.dig('B', 1), bond_t).should be_false
    end

    it "returns false when residue is itself" do
      structure = fake_structure include_bonds: true
      structure.dig('A', 1).bonded?(structure.dig('A', 1)).should be_false
      structure.dig('B', 1).bonded?(structure.dig('B', 1)).should be_false
    end
  end

  describe "#cis?" do
    it "returns true when residue is in the cis conformation" do
      load_file("cis-trans.pdb", topology: :templates).residues[2].cis?.should be_true
    end

    it "returns true when residue is not in the cis conformation" do
      load_file("cis-trans.pdb", topology: :templates).residues[1].cis?.should be_false
    end

    it "returns false when residue is at the start" do
      load_file("cis-trans.pdb", topology: :templates).residues[0].cis?.should be_false
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      structure = Chem::Structure.new
      chain = Chem::Chain.new 'A', structure
      Chem::Residue.new("TYR", 1, chain).inspect.should eq "<Residue A:TYR1>"
      Chem::Residue.new("ARG", 234, chain).inspect.should eq "<Residue A:ARG234>"
      chain = Chem::Chain.new 'B', structure
      Chem::Residue.new("ALA", 7453, chain).inspect.should eq "<Residue B:ALA7453>"
    end
  end

  describe "#name=" do
    it "sets kind from templates" do
      structure = Structure.new
      chain = Chain.new 'A', structure
      residue = Chem::Residue.new("TYR", 1, chain)
      residue.kind.protein?.should be_true
      residue.name = "HOH"
      residue.kind.solvent?.should be_true
      residue.name = "ULK"
      residue.kind.other?.should be_true
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
      load_file("cis-trans.pdb", topology: :templates).residues[1].trans?.should be_true
    end

    it "returns true when residue is not in the trans conformation" do
      load_file("cis-trans.pdb", topology: :templates).residues[2].trans?.should be_false
    end

    it "returns false when residue is at the start" do
      load_file("cis-trans.pdb", topology: :templates).residues[0].trans?.should be_false
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      residues = load_file("insertion_codes.pdb").residues
      residues[0].to_s.should eq "A:TRP75"
      residues[1].to_s.should eq "A:GLY75A"
      residues[2].to_s.should eq "A:SER75B"
      residues[-1].to_s.should eq "A:VAL76"
    end
  end
end
