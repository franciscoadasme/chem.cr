require "../spec_helper"

describe Chem::Residue do
  describe ".new" do
    it "sets kind from templates" do
      top = Chem::Topology.new
      chain = Chem::Chain.new 'A', top
      Chem::Residue.new("TYR", 1, chain).kind.protein?.should be_true
      Chem::Residue.new("HOH", 2, chain).kind.solvent?.should be_true
      Chem::Residue.new("ULK", 2, chain).kind.other?.should be_true
    end
  end

  describe "#<=>" do
    context "given insertion codes" do
      it "compares based on insertion codes" do
        residues = load_file("insertion_codes.pdb").residues
        (residues[0] <=> residues[1]).<(0).should be_true
        (residues[1] <=> residues[1]).should eq 0
        (residues[2] <=> residues[1]).>(0).should be_true
        (residues[0] <=> residues[-1]).<(0).should be_true
      end
    end

    context "given multiple chains" do
      it "compares based on chain id" do
        residues = load_file("5e5v.pdb").residues
        (residues[0] <=> residues[1]).<(0).should be_true
        (residues[1] <=> residues[1]).should eq 0
        (residues[2] <=> residues[1]).>(0).should be_true
        # same number, different chain
        (residues[0] <=> residues[7]).<(0).should be_true
      end
    end
  end

  describe "#[]" do
    it "raises when no atom matches atom type" do
      residue = fake_structure.residues[0]
      expect_raises IndexError do
        residue[Chem::AtomType.new("CX9", "C")]
      end
    end

    it "raises when atom names match but elements don't" do
      residue = fake_structure.residues[0]
      expect_raises IndexError do
        residue[Chem::AtomType.new("CA", "N")]
      end
    end
  end

  describe "#[]?" do
    it "returns atom that matches atom type" do
      residue = fake_structure.residues[0]
      residue[Chem::AtomType.new("CA", "C")]?.should eq residue["CA"]
      residue[Chem::AtomType.new("OD1", "O")]?.should eq residue["OD1"]
    end

    it "returns nil when no atom matches atom type" do
      residue = fake_structure.residues[0]
      residue[Chem::AtomType.new("CX9", "C")]?.should be_nil
    end

    it "returns nil when atom names match but elements don't" do
      residue = fake_structure.residues[0]
      residue[Chem::AtomType.new("CA", "N")]?.should be_nil
    end
  end

  describe "#bonded?" do
    a1, a2, b1 = fake_structure.residues

    context "given a residue" do
      it "tells if two residues are bonded through any pair of atoms" do
        a1.bonded?(a2).should be_true
        a2.bonded?(b1).should be_false
      end

      it "returns false when residue is itself" do
        a1.bonded?(a1).should be_false
      end
    end

    context "given a bond type" do
      it "tells if two residues are bonded" do
        bond_t = Chem::BondType.new Chem::AtomType.new("C", "C"), Chem::AtomType.new("N", "N")
        a1.bonded?(a2, bond_t).should be_true
        a2.bonded?(b1, bond_t).should be_false
      end

      it "tells if two residues are bonded by element-based search" do
        bond_t = Chem::BondType.new Chem::AtomType.new("C", "C"), Chem::AtomType.new("NX", "N")
        a1.bonded?(a2, bond_t, strict: false).should be_true
        a2.bonded?(b1, bond_t, strict: false).should be_false
      end

      it "returns false if bond is inverted" do
        bond_type = Chem::BondType.new(
          Chem::AtomType.new("N", "N"),
          Chem::AtomType.new("C", "C"),
        )
        a1.bonded?(a2, bond_type).should be_false
      end

      it "returns false if an atom if missing" do
        bond_type = Chem::BondType.new(
          Chem::AtomType.new("C", "C"),
          Chem::AtomType.new("CX1", "C"),
        )
        a1.bonded?(a2, bond_type).should be_false
      end

      it "returns false when residue is itself" do
        bond_type = Chem::BondType.new(
          Chem::AtomType.new("C", "C"),
          Chem::AtomType.new("N", "N"),
        )
        a1.bonded?(a1, bond_type).should be_false
      end

      it "returns false when bond order is different" do
        bond_type = Chem::BondType.new(
          Chem::AtomType.new("C", "C"),
          Chem::AtomType.new("N", "N"),
          2,
        )
        a1.bonded?(a2, bond_type).should be_false
      end
    end

    context "given two atom names" do
      it "tells if two residues are bonded" do
        a1.bonded?(a2, "C", "N").should be_true
        a2.bonded?(b1, "C", "N").should be_false
      end

      it "returns false when bond is inverted" do
        a1.bonded?(a2, "N", "C").should be_false
      end

      it "returns false when an atom if missing" do
        a1.bonded?(a2, "X", "Y").should be_false
      end

      it "returns false when residue is itself" do
        a1.bonded?(a1, "C", "N").should be_false
      end

      it "returns false when bond order is different" do
        a1.bonded?(a2, "C", "N", 2).should be_false
      end
    end

    context "given an atom type and element" do
      it "tells if two residues are bonded through atom type-element" do
        atom_t = Chem::AtomType.new "C", "C"
        a1.bonded?(a2, atom_t, Chem::PeriodicTable::N).should be_true
        a2.bonded?(b1, atom_t, Chem::PeriodicTable::N).should be_false
      end

      it "returns false when bond is inverted" do
        atom_t = Chem::AtomType.new "N", "N"
        a1.bonded?(a2, atom_t, Chem::PeriodicTable::C).should be_false
      end

      it "returns false when atom type is missing" do
        atom_t = Chem::AtomType.new "CY2", "C"
        a1.bonded?(a2, atom_t, Chem::PeriodicTable::N).should be_false
      end

      it "returns false when element is missing" do
        atom_t = Chem::AtomType.new "C", "C"
        a1.bonded?(a2, atom_t, Chem::PeriodicTable::Zn).should be_false
      end

      it "returns false when residue is itself" do
        atom_t = Chem::AtomType.new "C", "C"
        a1.bonded?(a1, atom_t, Chem::PeriodicTable::N).should be_false
      end

      it "returns false when bond order is different" do
        atom_t = Chem::AtomType.new "C", "C"
        a1.bonded?(a2, atom_t, Chem::PeriodicTable::N, 2).should be_false
      end
    end

    context "given an element and atom type" do
      it "tells if two residues are bonded through element-atom type" do
        atom_t = Chem::AtomType.new "N", "N"
        a1.bonded?(a2, Chem::PeriodicTable::C, atom_t).should be_true
        a2.bonded?(b1, Chem::PeriodicTable::C, atom_t).should be_false
      end

      it "returns false when bond is inverted" do
        atom_t = Chem::AtomType.new "C", "C"
        a1.bonded?(a2, Chem::PeriodicTable::N, atom_t).should be_false
      end

      it "returns false when atom type is missing" do
        atom_t = Chem::AtomType.new "NY2", "N"
        a1.bonded?(a2, Chem::PeriodicTable::C, atom_t).should be_false
      end

      it "returns false when element is missing" do
        atom_t = Chem::AtomType.new "N", "N"
        a1.bonded?(a2, Chem::PeriodicTable::Zn, atom_t).should be_false
      end

      it "returns false when residue is itself" do
        atom_t = Chem::AtomType.new "N", "N"
        a1.bonded?(a1, Chem::PeriodicTable::C, atom_t).should be_false
      end

      it "returns false when bond order is different" do
        atom_t = Chem::AtomType.new "N", "N"
        a1.bonded?(a2, Chem::PeriodicTable::C, atom_t, 2).should be_false
      end
    end

    context "given two elements" do
      it "tells if two residues are bonded through element-element" do
        a1.bonded?(a2, Chem::PeriodicTable::C, Chem::PeriodicTable::N).should be_true
        a2.bonded?(b1, Chem::PeriodicTable::C, Chem::PeriodicTable::N).should be_false
      end

      it "returns false when bond is inverted" do
        a1.bonded?(a2, Chem::PeriodicTable::N, Chem::PeriodicTable::C).should be_false
      end

      it "returns false when element is missing" do
        a1.bonded?(a2, Chem::PeriodicTable::Zn, Chem::PeriodicTable::N).should be_false
        a1.bonded?(a2, Chem::PeriodicTable::C, Chem::PeriodicTable::Zn).should be_false
      end

      it "returns false when residue is itself" do
        a1.bonded?(a1, Chem::PeriodicTable::C, Chem::PeriodicTable::N).should be_false
      end

      it "returns false when bond order is different" do
        a1.bonded?(a2, Chem::PeriodicTable::C, Chem::PeriodicTable::N, 2).should be_false
      end
    end
  end

  describe "#bonded_residues" do
    it "returns bonded residues" do
      residues = load_file("residue_kind_unknown_covalent_ligand.pdb").residues
      residues[0].bonded_residues.map(&.name).should eq %w(ALA)
      residues[1].bonded_residues.map(&.name).should eq %w(GLY CYS)
      residues[2].bonded_residues.map(&.name).should eq %w(ALA JG7)
      residues[3].bonded_residues.map(&.name).should eq %w(CYS)
    end

    context "given a bond type" do
      it "returns residues bonded via X(i)-Y(j)" do
        residues = load_file("residue_kind_unknown_covalent_ligand.pdb").residues
        c = Chem::AtomType.new("C", "C")
        n = Chem::AtomType.new("N", "N")
        bond_t = Chem::BondType.new(c, n)
        residues[0].bonded_residues(bond_t).map(&.name).should eq %w(ALA)
        residues[1].bonded_residues(bond_t).map(&.name).should eq %w(CYS)
        residues[2].bonded_residues(bond_t).map(&.name).should eq %w()
        residues[3].bonded_residues(bond_t).map(&.name).should eq %w()
      end

      it "returns residues bonded via X(i)-Y(j) or X(j)-Y(i)" do
        residues = load_file("residue_kind_unknown_covalent_ligand.pdb").residues
        c = Chem::AtomType.new("C", "C")
        n = Chem::AtomType.new("N", "N")
        bond_t = Chem::BondType.new(c, n)
        residues[0].bonded_residues(bond_t, forward_only: false).map(&.name).should eq %w(ALA)
        residues[1].bonded_residues(bond_t, forward_only: false).map(&.name).should eq %w(GLY CYS)
        residues[2].bonded_residues(bond_t, forward_only: false).map(&.name).should eq %w(ALA)
        residues[3].bonded_residues(bond_t, forward_only: false).map(&.name).should eq %w()
      end

      it "returns bonded residues using fuzzy search" do
        residues = load_file("residue_kind_unknown_covalent_ligand.pdb").residues
        c = Chem::AtomType.new("C", "C")
        n = Chem::AtomType.new("NX", "N")
        bond_t = Chem::BondType.new(c, n)
        residues[0].bonded_residues(bond_t, strict: false).map(&.name).should eq %w(ALA)
        residues[1].bonded_residues(bond_t, strict: false).map(&.name).should eq %w(CYS)
        residues[2].bonded_residues(bond_t, strict: false).map(&.name).should eq %w()
        residues[3].bonded_residues(bond_t, strict: false).map(&.name).should eq %w()
      end
    end

    context "given a periodic peptide chain" do
      it "returns two residues for every residue" do
        load_file("hlx_gly.poscar", guess_topology: true).each_residue do |residue|
          residue.bonded_residues.map(&.name).should eq %w(GLY GLY)
        end
      end
    end

    context "given water molecules" do
      it "returns an empty array" do
        load_file("waters.xyz").each_residue do |residue|
          residue.bonded_residues.empty?.should be_true
        end
      end
    end
  end

  describe "#cis?" do
    it "returns true when residue is in the cis conformation" do
      load_file("cis-trans.pdb").residues[2].cis?.should be_true
    end

    it "returns true when residue is not in the cis conformation" do
      load_file("cis-trans.pdb").residues[1].cis?.should be_false
    end

    it "returns false when residue is at the start" do
      load_file("cis-trans.pdb").residues[0].cis?.should be_false
    end
  end

  describe "#code" do
    it "returns the residue's code" do
      structure = load_file("3sgr.pdb")
      seqres = structure.dig('A').residues.select(&.protein?).join(&.code)
      seqres.should eq "GKLKVLGDVIEVGGKLKVLGDVIEV"
    end

    it "returns default if residue's code is unknown" do
      residues = load_file("3sgr.pdb").dig('A').residues
      residues.join(&.code).should eq "GKLKVLGDVIEVGGKLKVLGDVIEVXXX"
      residues.join(&.code('?')).should eq "GKLKVLGDVIEVGGKLKVLGDVIEV???"
    end
  end

  describe "#dextro?" do
    it "tells if it's dextrorotatory" do
      load_file("l-d-peptide.pdb").residues.map(&.dextro?).should eq [
        false, false, true, true, false, false,
      ]
    end
  end

  describe "#het?" do
    it "tells if it is a HET residue" do
      structure = load_file "1h1s.pdb"
      structure.dig('A', 56).het?.should be_false  # protein
      structure.dig('A', 1298).het?.should be_true # ligand
      structure.dig('A', 2181).het?.should be_true # water
    end
  end

  describe "#insertion_code" do
    it "updates residue position" do
      structure = load_file("insertion_codes.pdb")
      seqres = structure.dig('A').residues.select(&.protein?).join(&.code)
      seqres.should eq "WGSNKPV"
      residue = structure.dig('A', 75, 'C')
      structure.dig('A', 75).insertion_code = 'C'
      residue.insertion_code = nil
      seqres = structure.dig('A').residues.select(&.protein?).join(&.code)
      seqres.should eq "NGSWKPV"
    end
  end

  describe "#inspect" do
    it "returns a delimited string representation" do
      top = Chem::Topology.new
      chain = Chem::Chain.new 'A', top
      Chem::Residue.new("TYR", 1, chain).inspect.should eq "<Residue A:TYR1>"
      Chem::Residue.new("ARG", 234, chain).inspect.should eq "<Residue A:ARG234>"
      chain = Chem::Chain.new 'B', top
      Chem::Residue.new("ALA", 7453, chain).inspect.should eq "<Residue B:ALA7453>"
    end
  end

  describe "#levo?" do
    it "tells if it's levorotatory" do
      load_file("l-d-peptide.pdb").residues.map(&.levo?).should eq [
        false, true, false, false, true, false,
      ]
    end
  end

  describe "#name=" do
    it "sets kind from templates" do
      top = Chem::Topology.new
      chain = Chem::Chain.new 'A', top
      residue = Chem::Residue.new("TYR", 1, chain)
      residue.kind.protein?.should be_true
      residue.name = "HOH"
      residue.kind.solvent?.should be_true
      residue.name = "ULK"
      residue.kind.other?.should be_true
    end
  end

  describe "#number" do
    it "updates residue position" do
      structure = load_file("3sgr.pdb")
      seqres = structure.dig('B').residues.select(&.protein?).join(&.code)
      seqres.should eq "GKLKVLGDVIEVGGKLKVLGDVIEV"
      structure.dig('B', 10).number = 40
      seqres = structure.dig('B').residues.select(&.protein?).join(&.code)
      seqres.should eq "GKLKVLGDVIVGGKLKVLGDVIEVE"
    end
  end

  describe "#succ" do
    context "given a periodic peptide" do
      it "returns a residue for the last residue" do
        residues = load_file("hlx_gly.poscar", guess_topology: true).residues.map &.succ
        residues.map(&.try(&.number)).should eq (2..13).to_a + [1]
      end
    end
  end

  describe "#omega" do
    it "returns torsion angle omega" do
      st = fake_structure
      st.residues[1].omega.should be_close -179.87, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        st.residues[0].omega
      end
    end

    context "given a periodic peptide" do
      it "returns omega using minimum-image convention" do
        structure = load_file "hlx_gly.poscar", guess_topology: true
        structure.each_residue do |residue|
          residue.omega.should be_close -171.64, 1e-2
        end
      end
    end
  end

  describe "#omega?" do
    it "returns torsion angle omega" do
      st = fake_structure
      st.residues[1].omega?.should_not be_nil
      st.residues[1].omega?.not_nil!.should be_close -179.87, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure
      st.residues[0].omega?.should be_nil
    end
  end

  describe "#phi" do
    it "returns torsion angle phi" do
      st = fake_structure
      st.residues[1].phi.should be_close -57.87, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure
      expect_raises Chem::Error, "A:ASP1 is terminal" do
        st.residues[0].phi
      end
    end

    context "given a periodic peptide" do
      it "returns phi using minimum-image convention" do
        structure = load_file "hlx_gly.poscar", guess_topology: true
        structure.each_residue do |residue|
          residue.phi.should be_close -80.33, 1e-2
        end
      end
    end
  end

  describe "#phi?" do
    it "returns torsion angle phi" do
      st = fake_structure
      st.residues[1].phi?.should_not be_nil
      st.residues[1].phi?.not_nil!.should be_close -57.87, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure
      st.residues[0].phi?.should be_nil
    end
  end

  describe "#pred" do
    context "given a periodic peptide" do
      it "returns the last residue for the first one" do
        residues = load_file("hlx_gly.poscar", guess_topology: true).residues.map &.pred
        residues.map(&.try(&.number)).should eq [13] + (1..12).to_a
      end
    end
  end

  describe "#psi" do
    it "returns torsion angle psi" do
      st = fake_structure
      st.residues[0].psi.should be_close 127.28, 1e-2
    end

    it "fails when residue is at the start" do
      st = fake_structure
      expect_raises Chem::Error, "A:PHE2 is terminal" do
        st.residues[1].psi
      end
    end

    context "given a periodic peptide" do
      it "returns psi using minimum-image convention" do
        structure = load_file "hlx_gly.poscar", guess_topology: true
        structure.each_residue do |residue|
          residue.psi.should be_close 58.2, 1e-2
        end
      end
    end
  end

  describe "#psi?" do
    it "returns torsion angle psi" do
      st = fake_structure
      st.residues[0].psi?.should_not be_nil
      st.residues[0].psi?.not_nil!.should be_close 127.28, 1e-2
    end

    it "returns nil when residue is at the start" do
      st = fake_structure
      st.residues[1].psi?.should be_nil
    end
  end

  describe "#trans?" do
    it "returns true when residue is in the trans conformation" do
      load_file("cis-trans.pdb").residues[1].trans?.should be_true
    end

    it "returns true when residue is not in the trans conformation" do
      load_file("cis-trans.pdb").residues[2].trans?.should be_false
    end

    it "returns false when residue is at the start" do
      load_file("cis-trans.pdb").residues[0].trans?.should be_false
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

  describe "#water?" do
    it "tells if it is a water residue" do
      structure = load_file "1h1s.pdb"
      structure.dig('A', 56).water?.should be_false   # protein
      structure.dig('A', 1298).water?.should be_false # ligand
      structure.dig('A', 2181).water?.should be_true  # water
    end
  end
end
