require "./spec_helper"

describe Chem::AtomCollection do
  st = fake_structure

  describe "#atoms" do
    it "returns an atom view" do
      st.atoms.should be_a Chem::AtomView
    end
  end

  describe "#each_atom" do
    it "iterates over each atom when called with block" do
      ary = [] of Int32
      st.each_atom { |atom| ary << atom.serial }
      ary.should eq (1..25).to_a
    end

    it "returns an iterator when called without block" do
      st.each_atom.should be_a Iterator(Chem::Atom)
    end
  end

  describe "#n_atoms" do
    it "returns the number of atoms" do
      st.n_atoms.should eq 25
    end
  end
end

describe Chem::BondArray do
  describe "#[]" do
    st = fake_structure
    glu_cd = st.dig('A', 1, "CG")
    glu_oe1 = st.dig('A', 1, "OD1")
    glu_oe2 = st.dig('A', 1, "OD2")

    it "returns the bond for a given atom" do
      bond = glu_cd.bonds[glu_oe1]
      bond.other(glu_cd).should eq glu_oe1
    end

    it "fails when the bond does not exist" do
      expect_raises Chem::Error, "Atom 6 is not bonded to atom 9" do
        glu_cd.bonds[st.dig('A', 2, "N")]
      end
    end
  end

  describe "#[]?" do
    st = fake_structure
    glu_cd = st.dig('A', 1, "CG")
    glu_oe1 = st.dig('A', 1, "OD1")
    glu_oe2 = st.dig('A', 1, "OD2")

    it "returns the bond for a given atom" do
      bond = glu_cd.bonds[glu_oe1]
      bond.other(glu_cd).should eq glu_oe1
    end

    it "returns nil when the bond does not exist" do
      glu_cd.bonds[st.dig('A', 2, "N")]?.should be_nil
    end
  end

  describe "#add" do
    it "adds a new bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe1, :double

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "doesn't add an existing bond (inversed)" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      glu_cd.bonds.add glu_oe1, :double
      glu_oe1.bonds.add glu_cd

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end

    it "fails when adding a bond that doesn't have the primary atom" do
      st = fake_structure include_bonds: false
      glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]

      expect_raises Chem::Error, "Bond doesn't include atom 7" do
        glu_cd.bonds << Chem::Bond.new glu_oe1, glu_oe2
      end
    end

    # it "fails when adding a bond leads to an invalid valence" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double
    #   glu_cd.bonds.add glu_oe2

    #   expect_raises Chem::Error, "Atom 7 has only 1 valence electron available" do
    #     glu_cd.bonds.add st.atoms[5], :double
    #   end
    # end

    # it "fails when adding a bond leads to an invalid valence on secondary atom" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1

    #   expect_raises Chem::Error, "Atom 8 has only 1 valence electron available" do
    #     st.atoms[5].bonds.add glu_oe1, :double
    #   end
    # end

    # it "fails when the primary atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe1.bonds.add glu_oe2
    #   end
    # end

    # it "fails when the secondary atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe1, :double

    #   expect_raises Chem::Error, "Atom 8 has its valence shell already full" do
    #     glu_oe2.bonds.add glu_oe1
    #   end
    # end

    # it "fails when a charged atom has its valence shell already full" do
    #   st = fake_structure
    #   glu_cd, glu_oe1, glu_oe2 = st.atoms[6..8]
    #   glu_cd.bonds.add glu_oe2
    #   glu_oe2.charge.should eq -1

    #   expect_raises Chem::Error, "Atom 9 has its valence shell already full" do
    #     glu_oe2.bonds.add st.atoms[5], :double
    #   end
    # end
  end

  describe "#delete" do
    it "deletes an existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.add glu_oe2, :single

      glu_cd.bonds.delete glu_oe1
      glu_cd.bonds.size.should eq 1
      glu_oe1.bonds.size.should eq 0
    end

    it "doesn't delete a non-existing bond" do
      st = fake_structure include_bonds: false
      glu_cd = st.dig('A', 1, "CG")
      glu_oe1 = st.dig('A', 1, "OD1")
      glu_oe2 = st.dig('A', 1, "OD2")

      glu_cd.bonds.add glu_oe1, :double
      glu_cd.bonds.delete glu_oe2
      glu_cd.bonds.delete Chem::Bond.new(glu_cd, glu_oe2)

      glu_cd.bonds.size.should eq 1
      glu_cd.bonds[0].should be glu_oe1.bonds[0]
    end
  end
end

describe Chem::ChainCollection do
  st = fake_structure

  describe "#chains" do
    it "returns a chain view" do
      st.chains.should be_a Chem::ChainView
    end
  end

  describe "#each_chain" do
    it "iterates over each chain when called with block" do
      ary = [] of Char?
      st.each_chain { |chain| ary << chain.id }
      ary.should eq ['A', 'B']
    end

    it "returns an iterator when called without block" do
      st.each_chain.should be_a Iterator(Chem::Chain)
    end
  end

  describe "#n_chains" do
    it "returns the number of chains" do
      st.n_chains.should eq 2
    end
  end
end

describe Chem::ChainView do
  chains = fake_structure.chains

  describe "#[]" do
    it "gets chain by zero-based index" do
      chains[0].id.should eq 'A'
    end

    it "gets chain by identifier" do
      chains['A'].id.should eq 'A'
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      chains.size.should eq 2
    end
  end
end

describe Chem::Topology do
  describe "#delete" do
    it "deletes a chain" do
      top = Chem::Structure.build do
        3.times { chain { } }
      end.topology
      top.n_chains.should eq 3
      top.chains.map(&.id).should eq "ABC".chars

      top.delete top.chains[1]
      top.n_chains.should eq 2
      top.chains.map(&.id).should eq "AC".chars
      top.dig?('B').should be_nil
    end

    it "does not delete another chain with the same id from the internal table (#86)" do
      top = Chem::Topology.new
      Chem::Chain.new 'A', top
      Chem::Chain.new 'B', top
      Chem::Chain.new 'A', top

      top.n_chains.should eq 3
      top.chains.map(&.id).should eq "ABA".chars

      top.delete top.chains[0]

      top.n_chains.should eq 2
      top.chains.map(&.id).should eq "BA".chars
      top.dig('A').should be top.chains[1]
    end
  end

  describe "#dig" do
    top = fake_structure

    it "returns a chain" do
      top.dig('A').id.should eq 'A'
    end

    it "returns a residue" do
      top.dig('A', 2).name.should eq "PHE"
      top.dig('A', 2, nil).name.should eq "PHE"
    end

    it "returns an atom" do
      top.dig('A', 2, "CA").name.should eq "CA"
      top.dig('A', 2, nil, "CA").name.should eq "CA"
    end

    it "fails when index is invalid" do
      expect_raises(KeyError) { top.dig 'C' }
      expect_raises(KeyError) { top.dig 'A', 25 }
      expect_raises(KeyError) { top.dig 'A', 2, "OH" }
    end
  end

  describe "#dig?" do
    top = fake_structure

    it "returns nil when index is invalid" do
      top.dig?('C').should be_nil
      top.dig?('A', 25).should be_nil
      top.dig?('A', 2, "OH").should be_nil
    end
  end

  describe "#guess_bonds" do
    it "guesses bonds from geometry" do
      atoms = load_file("AlaIle--unwrapped.poscar").atoms
      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      atoms.each_with_index { |atom, i| atom.bonds.size.should eq n_bonds[i] }
      atoms[0].bonded_atoms.map(&.serial).sort!.should eq [2, 14, 15, 16]
      atoms[4].bonded_atoms.map(&.serial).sort!.should eq [4, 28, 30]
      atoms[4].bonds[atoms[27]].order.should eq 2
      atoms[4].bonds[atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      structure = load_file "k2p_pore_b.xyz"

      structure.bonds.size.should eq 644
      structure.bonds.sum(&.order).should eq 714
      structure.bonds.count(&.single?).should eq 574
      structure.bonds.count(&.double?).should eq 70

      structure.formal_charge.should eq 3
      structure.atoms.count(&.formal_charge.!=(0)).should eq 9

      # ions
      (638..641).each do |i|
        structure.atoms[i].valence.should eq 1
        structure.atoms[i].bonds.size.should eq 0
        structure.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      structure.atoms[324].valence.should eq 3
      structure.atoms[324].bonds.size.should eq 4
      structure.atoms[324].formal_charge.should eq 1

      # c-ter
      structure.atoms[364].valence.should eq 2
      structure.atoms[364].formal_charge.should eq -1
      structure.atoms[365].valence.should eq 2
      structure.atoms[365].formal_charge.should eq 0

      structure.atoms[149].bonded_atoms.map(&.serial).should eq [145] # H near two Os

      # aromatic ring
      structure.atoms[427].bonds[structure.atoms[428]].order.should eq 1
      structure.atoms[428].bonds[structure.atoms[430]].order.should eq 2
      structure.atoms[430].bonds[structure.atoms[432]].order.should eq 1
      structure.atoms[432].bonds[structure.atoms[431]].order.should eq 2
      structure.atoms[431].bonds[structure.atoms[429]].order.should eq 1
      structure.atoms[429].bonds[structure.atoms[427]].order.should eq 2
    end

    it "guesses bonds from geometry having a sulfate ion" do
      structure = load_file "sulbactam.xyz"

      structure.bonds.size.should eq 27
      structure.bonds.sum(&.order).should eq 31
      structure.bonds.count(&.single?).should eq 23
      structure.bonds.count(&.double?).should eq 4

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[13].valence.should eq 2
      structure.atoms[13].bonded_atoms.map(&.serial).sort!.should eq [13, 26]
      structure.atoms[14].valence.should eq 2
      structure.atoms[14].bonded_atoms.map(&.serial).should eq [13]

      # sulfate ion
      structure.atoms[3].valence.should eq 6
      structure.atoms[3].bonded_atoms.map(&.serial).sort!.should eq [2, 5, 6, 7]
      structure.atoms[3].bonds[structure.atoms[1]].single?.should be_true
      structure.atoms[3].bonds[structure.atoms[4]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[5]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[6]].single?.should be_true
    end

    it "guesses bonds from geometry of a protein having sulfur" do
      structure = load_file "acama.xyz"

      structure.bonds.size.should eq 60
      structure.bonds.sum(&.order).should eq 65
      structure.bonds.count(&.single?).should eq 55
      structure.bonds.count(&.double?).should eq 5

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[15].valence.should eq 2
      structure.atoms[15].bonded_atoms.map(&.serial).should eq [15, 21]
      structure.atoms[15].bonds[structure.atoms[14]].single?.should be_true
      structure.atoms[15].bonds[structure.atoms[20]].single?.should be_true

      structure.atoms[37].valence.should eq 2
      structure.atoms[37].bonded_atoms.map(&.serial).should eq [37, 39]
      structure.atoms[37].bonds[structure.atoms[36]].single?.should be_true
      structure.atoms[37].bonds[structure.atoms[38]].single?.should be_true
    end

    it "does not guess bond orders if hydrogens are missing" do
      structure = load_file "residue_kind_unknown_covalent_ligand.pdb"
      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.zero?.!).should eq 0
      structure.bonds.size.should eq 59
      structure.bonds.count(&.single?.!).should eq 3 # backbone C=O
    end
  end

  describe "#guess_residues" do
    it "guesses the topology of a dipeptide" do
      structure = load_file "AlaIle--unwrapped.poscar", guess_topology: true
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq %w(ALA ILE)
      structure.residues.map(&.number).should eq [1, 2]
      structure.residues.all?(&.protein?).should be_true
      structure.residues[0].atoms.map(&.name).should eq %w(
        N CA HA C O CB HB1 HB2 HB3 H1 H2)
      structure.residues[1].atoms.map(&.name).should eq %w(
        N H CA HA C O CB HB CG1 HG11 HG12 CD1 HD11 HD12 HD13 CG2 HG21 HG22 HG23 OXT HXT)
    end

    it "guesses the topology of two peptide chains" do
      structure = load_file "5e61--unwrapped.poscar", guess_topology: true
      structure.chains.map(&.id).should eq ['A', 'B']
      structure.each_chain do |chain|
        chain.residues.map(&.name).should eq %w(PHE GLY ALA ILE LEU SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues.all?(&.protein?).should be_true
        chain.residues[0].atoms.map(&.name).should eq %w(
          N CA HA C O CB HB1 HB2 CG CD1 HD1 CE1 HE1 CZ HZ CE2 HE2 CD2 HD2 H1 H2)
        chain.residues[5].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG)
        chain.residues[6].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG OXT HXT)
      end
    end

    it "guesses the topology of two peptides off-center (issue #3)" do
      chains = load_file("5e61--off-center.poscar", guess_topology: true).chains
      chains.map(&.id).should eq ['A', 'B']
      chains.each do |chain|
        chain.residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues.all?(&.protein?).should be_true
      end
    end

    it "guesses the topology of a broken peptide with waters" do
      chains = load_file("5e5v--unwrapped.poscar", guess_topology: true).chains
      chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      chains[0].residues.map(&.name).sort!.should eq %w(ALA ASN GLY ILE LEU PHE SER)
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.all?(&.protein?).should be_true
      chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER UNK)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.all?(&.protein?).should be_true
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[2].residues.all?(&.solvent?).should be_true
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]
      chains[3].residues.all?(&.other?).should be_true
    end

    it "guesses the topology of a periodic peptide" do
      chains = load_file("hlx_gly.poscar", guess_topology: true).chains
      chains.map(&.id).should eq ['A']
      chains[0].residues.map(&.name).should eq ["GLY"] * 13
      chains[0].residues.map(&.number).should eq (1..13).to_a
      chains[0].residues.all?(&.protein?).should be_true
    end

    it "guesses the topology of many fragments (beyond max chain id)" do
      structure = load_file "many_fragments.poscar", guess_topology: true
      structure.n_chains.should eq 1
      structure.n_residues.should eq 144
      structure.fragments.size.should eq 72
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq ["PHE"] * 144
      structure.residues.map(&.number).should eq (1..144).to_a
      structure.residues.all?(&.protein?).should be_true
    end

    it "detects multiple residues for unmatched atoms (#16)" do
      structure = load_file "peptide_unknown_residues.xyz", guess_topology: true
      structure.n_residues.should eq 9
      structure.residues.map(&.name).should eq %w(ALA LEU UNK VAL THR LEU SER UNK ALA)
      structure.residues[2].n_atoms.should eq 14
      structure.residues[7].n_atoms.should eq 8
      structure.residues.all?(&.protein?).should be_true
    end

    it "renames unmatched atoms" do
      structure = load_file("peptide_unknown_residues.xyz", guess_topology: true)
      structure.dig('A', 3).name.should eq "UNK"
      structure.dig('A', 3).atoms.map(&.name).should eq %w(N1 C1 C2 O1 C3 O2 H1 H2 H3 H4 C4 H5 H6 H7)
      structure.dig('A', 8).name.should eq "UNK"
      structure.dig('A', 8).atoms.map(&.name).should eq %w(N1 C1 C2 O1 S1 H1 H2 H3)
    end

    it "guesses the topology of non-standard atoms (#21)" do
      structure = load_file "5e5v.pdb"
      structure.dig('A', 1, "N").bonded_atoms.map(&.name).sort!.should eq %w(CA H1 H2 H3)
      structure.dig('A', 1, "N").bonds.map(&.order).sort!.should eq [1, 1, 1, 1]
      structure.dig('A', 1, "N").formal_charge.should eq 1
      structure.dig('A', 7, "OXT").bonded_atoms.map(&.name).should eq %w(C)
      structure.dig('A', 7, "OXT").bonds.map(&.order).sort!.should eq [1]
      structure.dig('A', 7, "OXT").formal_charge.should eq -1
      structure.dig('B', 1, "N").bonded_atoms.map(&.name).sort!.should eq %w(CA H1 H2 H3)
      structure.dig('B', 1, "N").bonds.map(&.order).sort!.should eq [1, 1, 1, 1]
      structure.dig('B', 1, "N").formal_charge.should eq 1
      structure.dig('B', 7, "OXT").bonded_atoms.map(&.name).should eq %w(C)
      structure.dig('B', 7, "OXT").bonds.map(&.order).sort!.should eq [1]
      structure.dig('B', 7, "OXT").formal_charge.should eq -1
    end

    it "guesses the topology of a entire protein" do
      expected = load_file "1h1s_a--prepared.pdb"
      structure = Chem::Structure.from_xyz IO::Memory.new(expected.to_xyz)
      structure.topology.guess_names
      structure.residues.join(&.code).should eq expected.residues.join(&.code)
    end
  end

  describe "#guess_topology" do
    context "given a molecule with topology" do
      it "guesses bonds of unknown residues" do
        structure = load_file "residue_kind_unknown_covalent_ligand.pdb"
        structure.dig('A', 148, "C20").bonded?(structure.dig('A', 147, "SG")).should be_true
        structure.dig('A', 148, "C20").bonded?(structure.dig('A', 148, "N21")).should be_true
        structure.dig('A', 148, "S2").bonded?(structure.dig('A', 148, "O23")).should be_true
      end

      it "guesses kind of unknown residue when previous is known" do
        st = load_file "residue_kind_unknown_previous.pdb"
        st.residues[1].protein?.should be_true
      end

      it "guesses kind of unknown residue when next is known" do
        st = load_file "residue_kind_unknown_next.pdb"
        st.residues[0].protein?.should be_true
      end

      it "guesses kind of unknown residue when its flanked by known residues" do
        st = load_file "residue_kind_unknown_flanked.pdb"
        st.residues[1].protein?.should be_true
      end

      it "does not guess kind of unknown residue" do
        st = load_file "residue_kind_unknown_single.pdb"
        st.residues[0].other?.should be_true
      end

      it "does not guess kind of unknown residue when its not connected to others" do
        st = load_file "residue_kind_unknown_next_gap.pdb"
        st.residues.first.other?.should be_true
      end

      it "does not guess kind of unknown residue when it's not bonded by link bond" do
        structure = load_file "residue_kind_unknown_covalent_ligand.pdb"
        structure.residues.map(&.kind.to_s).should eq %w(Protein Protein Protein Other)
      end

      it "guess kind of unknown residue with non-standard atom names" do
        st = load_file "residue_unknown_non_standard_names.pdb"
        st.residues.all?(&.protein?).should be_true
      end

      it "guesses bonds between terminal residues (periodic)" do
        structure = load_file "polyala--theta-240.000--c-24.70.pdb"
        structure.each_residue do |residue|
          residue.pred.should_not be_nil
          residue.succ.should_not be_nil
        end
      end
    end

    it "assigns bond orders for a structure without hydrogens" do
      structure = Chem::Structure.build do
        residue "ICN" do
          atom :i, vec3(3.149, 0, 0)
          atom :c, vec3(1.148, 0, 0)
          atom :n, vec3(0, 0, 0)
          # bond "I1", "C1"
          # bond "C1", "N1", order: 3
        end
      end
      structure.bonds.size.should eq 2
      structure.dig('A', 1, "I1").bonds[structure.dig('A', 1, "C1")].order.should eq 1
      structure.dig('A', 1, "C1").bonds[structure.dig('A', 1, "N1")].order.should eq 3
    end
  end

  describe "residue templates" do
    it "assigns bonds, formal charges, and residue types" do
      structure = fake_structure
      r1, r2, r3 = structure.residues

      [r1, r2, r3].all?(&.protein?).should be_true
      [r1, r2, r3].map(&.formal_charge).should eq [-1, 0, 0]

      r1.bonded?(r2).should be_true
      r1.bonded?(r3).should be_false
      r2.bonded?(r1).should be_true
      r2.bonded?(r3).should be_false

      r1["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r1["N"].bonds[r1["CA"]].order.should eq 1
      r1["CA"].bonds[r1["C"]].order.should eq 1
      r1["C"].bonds[r1["O"]].order.should eq 2
      r1["CA"].bonds[r1["CB"]].order.should eq 1
      r1["CB"].bonds[r1["CG"]].order.should eq 1
      r1["CG"].bonds[r1["OD1"]].order.should eq 2
      r1["CG"].bonds[r1["OD2"]].order.should eq 1

      r1["C"].bonded_atoms.map(&.name).should eq ["CA", "O", "N"]
      r2["N"].bonded_atoms.map(&.name).should eq ["CA", "C"]

      r2["N"].bonds[r2["CA"]].order.should eq 1
      r2["CA"].bonds[r2["C"]].order.should eq 1
      r2["C"].bonds[r2["O"]].order.should eq 2
      r2["CA"].bonds[r2["CB"]].order.should eq 1
      r2["CB"].bonds[r2["CG"]].order.should eq 1
      r2["CG"].bonds[r2["CD1"]].order.should eq 2
      r2["CD1"].bonds[r2["CE1"]].order.should eq 1
      r2["CE1"].bonds[r2["CZ"]].order.should eq 2
      r2["CZ"].bonds[r2["CE2"]].order.should eq 1
      r2["CE2"].bonds[r2["CD2"]].order.should eq 2
      r2["CD2"].bonds[r2["CG"]].order.should eq 1

      r2["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
      r3["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r3["N"].bonds[r3["CA"]].order.should eq 1
      r3["CA"].bonds[r3["C"]].order.should eq 1
      r3["C"].bonds[r3["O"]].order.should eq 2
      r3["CA"].bonds[r3["CB"]].order.should eq 1
      r3["CB"].bonds[r3["OG"]].order.should eq 1

      r3["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
    end

    it "does not connect consecutive residues when there are far away" do
      structure = load_file "protein_gap.pdb"
      r1, r2, r3, r4 = structure.residues
      r1["C"].bonds[r2["N"]]?.should_not be_nil
      r2["C"].bonds[r3["N"]]?.should be_nil
      r3["C"].bonds[r4["N"]]?.should_not be_nil
    end
  end

  describe "#assign_formal_charges" do
    it "works for methane" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0.00000, 0.00000, 0.00000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, -0.51380, 0.89000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, 1.02770, 0.00000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, -0.51380, -0.89000)
        atom Chem::PeriodicTable::H, vec3(1.09000, 0.00000, 0.00000)
        bond 0, 1
        bond 0, 2
        bond 0, 3
        bond 0, 4
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0]
    end

    it "works for ammonia" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::N, vec3(-2.10870, 1.82800, 0.04300)
        atom Chem::PeriodicTable::H, vec3(-1.24270, 1.97310, 0.54230)
        atom Chem::PeriodicTable::H, vec3(-2.70480, 2.63480, 0.16060)
        atom Chem::PeriodicTable::H, vec3(-2.57490, 1.00960, 0.40750)
        bond 0, 1
        bond 0, 2
        bond 0, 3
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0]
    end

    it "works for ammonium" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::N, vec3(-2.10870, 1.82800, 0.04300)
        atom Chem::PeriodicTable::H, vec3(-1.24270, 1.97310, 0.54230)
        atom Chem::PeriodicTable::H, vec3(-2.70480, 2.63480, 0.16060)
        atom Chem::PeriodicTable::H, vec3(-2.57490, 1.00960, 0.40750)
        atom Chem::PeriodicTable::H, vec3(-1.91280, 1.69450, -0.93870)
        bond 0, 1
        bond 0, 2
        bond 0, 3
        bond 0, 4
      end
      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1, 0, 0, 0, 0]
    end

    it "works for cyanide" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
        atom Chem::PeriodicTable::N, vec3(1.16, 0, 0)
        bond 0, 1, order: 3
      end
      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1, 0]
    end

    it "works for ozone" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(-0.97960, 1.34290, 0.19110)
        atom Chem::PeriodicTable::O, vec3(-0.18710, 0.62720, -0.20810)
        atom Chem::PeriodicTable::O, vec3(0.47750, 0.03050, 0.50030)
        bond 0, 1, order: 1
        bond 1, 2, order: 2
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [-1, 1, 0]
    end

    it "works for divalent sulfur (SF2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.46830, 1.15280, -0.38900)
        atom Chem::PeriodicTable::F, vec3(-1.04840, 1.50510, 0.71990)
        atom Chem::PeriodicTable::F, vec3(-1.15490, 0.56490, -1.32330)
        bond 0, 1
        bond 0, 2
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0]
    end

    it "works for divalent sulfur (SO2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.25380, -0.14690, 0.13990)
        atom Chem::PeriodicTable::O, vec3(0.49180, -1.10210, -0.75260)
        atom Chem::PeriodicTable::O, vec3(-0.99950, 0.80830, 1.03240)
        bond 0, 1, order: 2
        bond 0, 2, order: 2
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0]
    end

    it "works for divalent sulfur (SO2+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.78990, 1.25770, -1.15060)
        atom Chem::PeriodicTable::O, vec3(-0.92360, 0.95430, 0.30200)
        atom Chem::PeriodicTable::O, vec3(-0.31430, -0.07080, -1.67910)
        bond 0, 1
        bond 0, 2, order: 2
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [1, -1, 0]
    end

    it "works for tetravalent sulfur (SO4)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-1.02600, -0.68670, -1.14420)
        atom Chem::PeriodicTable::O, vec3(-1.11420, -1.11800, 0.25940)
        atom Chem::PeriodicTable::O, vec3(-1.48400, 0.65740, -0.75990)
        atom Chem::PeriodicTable::O, vec3(-0.56800, -2.03070, -1.52840)
        atom Chem::PeriodicTable::O, vec3(-0.93780, -0.25540, -2.54770)
        bond 0, 1
        bond 0, 2, order: 2
        bond 0, 3
        bond 0, 4, order: 2
      end
      structure.formal_charge.should eq -2
      structure.atoms.map(&.formal_charge).should eq [0, -1, 0, -1, 0]
    end

    it "works for hexavalent sulfur (SF6)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-1.81210, 0.40270, -1.91430)
        atom Chem::PeriodicTable::F, vec3(-1.52680, -0.97430, -1.11400)
        atom Chem::PeriodicTable::F, vec3(-2.03870, 0.33540, -0.31370)
        atom Chem::PeriodicTable::F, vec3(-2.32400, 1.71240, -1.11400)
        atom Chem::PeriodicTable::F, vec3(-2.09740, 1.77960, -2.71470)
        atom Chem::PeriodicTable::F, vec3(-1.58560, 0.46990, -3.51500)
        atom Chem::PeriodicTable::F, vec3(-1.30030, -0.90710, -2.71470)
        bond 0, 1
        bond 0, 2
        bond 0, 3
        bond 0, 4
        bond 0, 5
        bond 0, 6
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0, 0]
    end

    it "works for divalent phosphorus (PO2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(-2.21100, -0.48150, -2.72450)
        atom Chem::PeriodicTable::O, vec3(-2.50240, -2.12750, -2.57730)
        atom Chem::PeriodicTable::O, vec3(-0.63530, -0.52300, -2.09580)
        bond 0, 1
        bond 0, 2, order: 2
      end
      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [0, -1, 0]
    end

    pending "works for tetravalent phosphorus (PO4)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(0.0000, -0.0001, 0.0000)
        atom Chem::PeriodicTable::O, vec3(1.5234, -0.0688, -0.1977)
        atom Chem::PeriodicTable::O, vec3(-0.6406, 0.7180, -1.1991)
        atom Chem::PeriodicTable::O, vec3(-0.5679, -1.4248, 0.1073)
        atom Chem::PeriodicTable::O, vec3(-0.3149, 0.7757, 1.2895)
        bond 0, 1, order: 2
        bond 0, 2
        bond 0, 3
        bond 0, 4
      end
      structure.formal_charge.should eq -3
      structure.atoms.map(&.formal_charge).should eq [0, 0, -1, -1, -1]
    end

    it "works for hexavalent phosphorus (PCl5)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(-0.0000, 0.0000, 0.0000)
        atom Chem::PeriodicTable::Cl, vec3(1.8770, 0.0000, 0.0000)
        atom Chem::PeriodicTable::Cl, vec3(-1.8770, -0.0000, 0.0000)
        atom Chem::PeriodicTable::Cl, vec3(-0.0000, 1.8770, 0.0000)
        atom Chem::PeriodicTable::Cl, vec3(-0.0000, -0.9385, 1.6255)
        atom Chem::PeriodicTable::Cl, vec3(-0.0000, -0.9385, -1.6255)
        bond 0, 1
        bond 0, 2
        bond 0, 3
        bond 0, 4
        bond 0, 5
      end
      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "works for hexavalent phosphorus (PF6)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(7.4422, -3.0649, -0.0994)
        atom Chem::PeriodicTable::F, vec3(8.0794, -1.8918, -0.6863)
        atom Chem::PeriodicTable::F, vec3(7.7625, -3.7851, -1.3259)
        atom Chem::PeriodicTable::F, vec3(6.2011, -2.6421, -0.7360)
        atom Chem::PeriodicTable::F, vec3(6.3939, -3.2101, 0.9025)
        atom Chem::PeriodicTable::F, vec3(7.9365, -4.3738, 0.3077)
        atom Chem::PeriodicTable::F, vec3(8.2813, -2.4845, 0.9418)
        bond 0, 1
        bond 0, 2
        bond 0, 3
        bond 0, 4
        bond 0, 5
        bond 0, 6
      end
      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1, 0, 0, 0, 0, 0, 0]
    end

    it "works for monoatomic cations (K+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::K, vec3(0, 0, 0)
      end
      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1]
    end

    it "works for monoatomic cations (Mg2+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Mg, vec3(0, 0, 0)
      end
      structure.formal_charge.should eq 2
      structure.atoms.map(&.formal_charge).should eq [2]
    end

    it "works for monoatomic anions" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Cl, vec3(0, 0, 0)
      end
      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1]
    end
  end

  describe "#renumber_residues_by" do
    it "renumbers residues by the given order" do
      top = load_file("3sgr.pdb").topology
      expected = top.chains.map { |chain| chain.residues.sort_by!(&.code) }
      top.renumber_residues_by(&.code)
      top.chains.map(&.residues).should eq expected
    end
  end

  describe "#renumber_residues_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      top = load_file("5e5v--unwrapped.poscar", guess_topology: true).topology
      top.renumber_residues_by_connectivity split_chains: false

      chains = top.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].pred.should be_nil
      chains[0].residues[3].pred.try(&.name).should eq "GLY"
      chains[0].residues[3].succ.try(&.name).should eq "ILE"
      chains[0].residues[-1].succ.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      top = load_file("hlx_gly.poscar").topology
      top.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.succ.should eq b
        b.pred.should eq a
      end
    end

    it "does not depend on current residue numbering (#82)" do
      [
        "polyala-trp--theta-80.000--c-19.91.poscar",
        "polyala-trp--theta-180.000--c-10.00.poscar",
      ].each do |filename|
        top = load_file(filename, guess_topology: true).topology
        top.renumber_residues_by_connectivity
        residues = top.residues.to_a.sort_by(&.number)
        residues.map(&.number).should eq (1..residues.size).to_a
        residues.each_with_index do |residue, i|
          j = i + 1
          j = 0 if j >= residues.size
          residues[j].number.should eq j + 1
          residue.bonded?(residues[j]).should be_true
        end
      end
    end

    it "does not split chains (#85)" do
      top = load_file("cylindrin--size-09.pdb").topology
      top.renumber_residues_by_connectivity split_chains: false
      top.chains.map(&.id).should eq "ABC".chars
      top.chains.map(&.n_residues).should eq [18] * 3
      top.chains.map(&.residues.map(&.number)).should eq [(1..18).to_a] * 3
      top.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 3
    end

    it "splits chains (#85)" do
      top = load_file("cylindrin--size-09.pdb").topology
      top.renumber_residues_by_connectivity split_chains: true
      top.chains.map(&.id).should eq "ABCDEF".chars
      top.chains.map(&.n_residues).should eq [9] * 6
      top.chains.map(&.residues.map(&.number)).should eq [(1..9).to_a] * 6
      top.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 6
    end
  end
end
