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

      expect_raises Chem::Error, "Bond doesn't include <Atom A:ASP1:OD1(7)>" do
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
      Chem::Chain.new top, 'A'
      Chem::Chain.new top, 'B'
      Chem::Chain.new top, 'A'

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
      top = load_file("AlaIle--unwrapped.poscar").topology
      top.guess_bonds

      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      top.atoms.zip(n_bonds) do |atom, bonds|
        atom.bonds.size.should eq bonds
      end
      top.atoms[0].bonded_atoms.map(&.serial).sort!.should eq [2, 14, 15, 16]
      top.atoms[4].bonded_atoms.map(&.serial).sort!.should eq [4, 28, 30]
      top.atoms[4].bonds[top.atoms[27]].order.should eq 2
      top.atoms[4].bonds[top.atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      top = load_file("k2p_pore_b.xyz").topology
      top.guess_bonds
      top.guess_formal_charges

      top.bonds.size.should eq 644
      top.bonds.sum(&.order.to_i).should eq 714
      top.bonds.count(&.single?).should eq 574
      top.bonds.count(&.double?).should eq 70

      top.formal_charge.should eq 3
      top.atoms.count(&.formal_charge.!=(0)).should eq 9

      # ions
      (638..641).each do |i|
        top.atoms[i].valence.should eq 0
        top.atoms[i].bonds.size.should eq 0
        top.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      top.atoms[324].valence.should eq 4
      top.atoms[324].bonds.size.should eq 4
      top.atoms[324].formal_charge.should eq 1

      # c-ter
      top.atoms[364].valence.should eq 1
      top.atoms[364].formal_charge.should eq -1
      top.atoms[365].valence.should eq 2
      top.atoms[365].formal_charge.should eq 0

      top.atoms[149].bonded_atoms.map(&.serial).should eq [145] # H near two Os

      # aromatic ring
      top.atoms[427].bonds[top.atoms[428]].order.should eq 1
      top.atoms[428].bonds[top.atoms[430]].order.should eq 2
      top.atoms[430].bonds[top.atoms[432]].order.should eq 1
      top.atoms[432].bonds[top.atoms[431]].order.should eq 2
      top.atoms[431].bonds[top.atoms[429]].order.should eq 1
      top.atoms[429].bonds[top.atoms[427]].order.should eq 2
    end

    it "guesses bonds from geometry having a sulfate ion" do
      top = load_file("sulbactam.xyz").topology
      top.guess_bonds
      top.guess_formal_charges

      top.bonds.size.should eq 27
      top.bonds.sum(&.order.to_i).should eq 31
      top.bonds.count(&.single?).should eq 23
      top.bonds.count(&.double?).should eq 4

      top.formal_charge.should eq 0
      top.atoms.count(&.formal_charge.!=(0)).should eq 0

      top.atoms[13].valence.should eq 2
      top.atoms[13].bonded_atoms.map(&.serial).sort!.should eq [13, 26]
      top.atoms[14].valence.should eq 2
      top.atoms[14].bonded_atoms.map(&.serial).should eq [13]

      # sulfate ion
      top.atoms[3].valence.should eq 6
      top.atoms[3].bonded_atoms.map(&.serial).sort!.should eq [2, 5, 6, 7]
      top.atoms[3].bonds[top.atoms[1]].single?.should be_true
      top.atoms[3].bonds[top.atoms[4]].double?.should be_true
      top.atoms[3].bonds[top.atoms[5]].double?.should be_true
      top.atoms[3].bonds[top.atoms[6]].single?.should be_true
    end

    it "guesses bonds from geometry of a protein having sulfur" do
      top = load_file("acama.xyz").topology
      top.guess_bonds
      top.guess_formal_charges

      top.bonds.size.should eq 60
      top.bonds.sum(&.order.to_i).should eq 65
      top.bonds.count(&.single?).should eq 55
      top.bonds.count(&.double?).should eq 5

      top.formal_charge.should eq 0
      top.atoms.count(&.formal_charge.!=(0)).should eq 0

      top.atoms[15].valence.should eq 2
      top.atoms[15].bonded_atoms.map(&.serial).should eq [15, 21]
      top.atoms[15].bonds[top.atoms[14]].single?.should be_true
      top.atoms[15].bonds[top.atoms[20]].single?.should be_true

      top.atoms[37].valence.should eq 2
      top.atoms[37].bonded_atoms.map(&.serial).should eq [37, 39]
      top.atoms[37].bonds[top.atoms[36]].single?.should be_true
      top.atoms[37].bonds[top.atoms[38]].single?.should be_true
    end

    it "guesses bonds of unknown residues" do
      top = load_file("residue_type_unknown_covalent_ligand.pdb").topology
      top.guess_bonds

      top.dig('A', 148, "C20").bonded?(top.dig('A', 147, "SG")).should be_true
      top.dig('A', 148, "C20").bonded?(top.dig('A', 148, "N21")).should be_true
      top.dig('A', 148, "S2").bonded?(top.dig('A', 148, "O23")).should be_true
    end

    it "guesses bonds between terminal residues (periodic)" do
      top = load_file("polyala--theta-240.000--c-24.70.pdb").topology
      top.guess_bonds

      top.each_residue do |residue|
        residue.pred?.should_not be_nil
        residue.succ?.should_not be_nil
      end
    end

    it "guesses bond order between atoms far apart in a periodic structure (#164)" do
      structure = load_file "polyala-beta--theta-180.000--c-10.00.poscar"
      structure.topology.guess_bonds
      structure.topology.guess_names
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0
      structure.dig('A', 5, "C").bonds[structure.dig('A', 5, "O")].order.should eq 2
      structure.dig('B', 5, "C").bonds[structure.dig('B', 5, "O")].order.should eq 2
    end

    it "increases bond order of multi-valent atoms first" do
      structure = load_file("dmpe.xyz")
      structure.topology.guess_bonds
      structure.topology.guess_formal_charges
      structure.bonds.select(&.double?)
        .map(&.atoms.map(&.name).to_a)
        .should eq [%w(P1 O1), %w(C5 O6), %w(C8 O8)]
      structure.atoms.reject(&.formal_charge.zero?)
        .to_h { |atom| {atom.name, atom.formal_charge} }
        .should eq({"N1" => 1, "O2" => -1})
    end
  end

  describe "#guess_names" do
    it "guesses the topology of a dipeptide" do
      top = load_file("AlaIle--unwrapped.poscar").topology
      top.guess_bonds
      top.guess_names

      top.chains.map(&.id).should eq ['A']
      top.residues.map(&.name).should eq %w(ALA ILE)
      top.residues.map(&.number).should eq [1, 2]
      top.residues.all?(&.protein?).should be_true
      top.residues[0].atoms.map(&.name).should eq %w(
        N H1 H2 CA HA C O CB HB1 HB2 HB3)
      top.residues[1].atoms.map(&.name).should eq %w(
        N H CA HA C O OXT HXT CB HB CG1 HG11 HG12 CD1 HD11 HD12 HD13 CG2 HG21 HG22 HG23)
    end

    it "guesses the topology of two peptide chains" do
      top = load_file("5e61--unwrapped.poscar").topology
      top.guess_bonds
      top.guess_names

      top.chains.map(&.id).should eq ['A', 'B']
      top.each_chain do |chain|
        chain.residues.map(&.name).should eq %w(PHE GLY ALA ILE LEU SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues.all?(&.protein?).should be_true
        chain.residues[0].atoms.map(&.name).should eq %w(
          N H1 H2 CA HA C O CB HB1 HB2 CG CD1 HD1 CE1 HE1 CZ HZ CE2 HE2 CD2 HD2)
        chain.residues[5].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG)
        chain.residues[6].atoms.map(&.name).should eq %w(
          N H CA HA C O OXT HXT CB HB1 HB2 OG HG)
      end
    end

    it "guesses the topology of two peptides off-center (issue #3)" do
      top = load_file("5e61--off-center.poscar").topology
      top.guess_bonds
      top.guess_names

      top.chains.map(&.id).should eq ['A', 'B']
      top.chains.each do |chain|
        chain.residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues.all?(&.protein?).should be_true
      end
    end

    it "guesses the topology of a broken peptide with waters" do
      top = load_file("5e5v--unwrapped.poscar").topology
      top.guess_bonds
      top.guess_names

      top.chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      top.chains[0].residues.map(&.name).sort!.should eq %w(ALA ASN GLY ILE LEU PHE SER)
      top.chains[0].residues.map(&.number).should eq (1..7).to_a
      top.chains[0].residues.all?(&.protein?).should be_true
      top.chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER UNK)
      top.chains[1].residues.map(&.number).should eq (1..7).to_a
      top.chains[1].residues.all?(&.protein?).should be_true
      top.chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      top.chains[2].residues.map(&.number).should eq (1..7).to_a
      top.chains[2].residues.all?(&.solvent?).should be_true
      top.chains[3].residues.map(&.name).should eq %w(UNK)
      top.chains[3].residues.map(&.number).should eq [1]
      top.chains[3].residues.all?(&.other?).should be_true
    end

    it "guesses the topology of a periodic peptide" do
      top = load_file("hlx_gly.poscar").topology
      top.guess_bonds
      top.guess_names

      top.chains.map(&.id).should eq ['A']
      top.chains[0].residues.map(&.name).should eq ["GLY"] * 13
      top.chains[0].residues.map(&.number).should eq (1..13).to_a
      top.chains[0].residues.all?(&.protein?).should be_true
    end

    it "guesses the topology of many fragments (beyond max chain id)" do
      top = load_file("many_fragments.poscar").topology
      top.guess_bonds
      top.guess_names

      top.n_chains.should eq 1
      top.n_residues.should eq 144
      top.fragments.size.should eq 72
      top.chains.map(&.id).should eq ['A']
      top.residues.map(&.name).should eq ["PHE"] * 144
      top.residues.map(&.number).should eq (1..144).to_a
      top.residues.all?(&.protein?).should be_true
    end

    it "detects multiple residues for unmatched atoms (#16)" do
      top = load_file("peptide_unknown_residues.xyz").topology
      top.guess_bonds
      top.guess_names

      top.n_residues.should eq 9
      top.residues.map(&.name).should eq %w(ALA LEU UNK VAL THR LEU SER UNK ALA)
      top.residues[2].n_atoms.should eq 14
      top.residues[7].n_atoms.should eq 8
      top.residues.all?(&.protein?).should be_true
    end

    it "renames unmatched atoms" do
      top = load_file("peptide_unknown_residues.xyz").topology
      top.guess_bonds
      top.guess_names

      top.dig('A', 3).name.should eq "UNK"
      top.dig('A', 3).atoms.map(&.name).should eq %w(N1 C1 C2 O1 C3 O2 H1 H2 H3 H4 C4 H5 H6 H7)
      top.dig('A', 8).name.should eq "UNK"
      top.dig('A', 8).atoms.map(&.name).should eq %w(N1 C1 C2 O1 S1 H1 H2 H3)
    end

    it "guesses the topology of non-standard atoms (#21)" do
      top = load_file("5e5v.pdb").topology
      top.guess_bonds
      top.guess_formal_charges
      top.guess_names

      top.dig('A', 1, "N").bonded_atoms.map(&.name).sort!.should eq %w(CA H1 H2 H3)
      top.dig('A', 1, "N").bonds.map(&.order).sort!.should eq [1, 1, 1, 1]
      top.dig('A', 1, "N").formal_charge.should eq 1
      top.dig('A', 7, "OXT").bonded_atoms.map(&.name).should eq %w(C)
      top.dig('A', 7, "OXT").bonds.map(&.order).sort!.should eq [1]
      top.dig('A', 7, "OXT").formal_charge.should eq -1
      top.dig('B', 1, "N").bonded_atoms.map(&.name).sort!.should eq %w(CA H1 H2 H3)
      top.dig('B', 1, "N").bonds.map(&.order).sort!.should eq [1, 1, 1, 1]
      top.dig('B', 1, "N").formal_charge.should eq 1
      top.dig('B', 7, "OXT").bonded_atoms.map(&.name).should eq %w(C)
      top.dig('B', 7, "OXT").bonds.map(&.order).sort!.should eq [1]
      top.dig('B', 7, "OXT").formal_charge.should eq -1
    end

    it "guesses the topology of an entire protein" do
      structure = load_file "1h1s_a--prepared.pdb"
      expected = structure.residues.join(&.code)

      structure = Chem::Structure.from_xyz IO::Memory.new(structure.to_xyz)
      structure.topology.guess_bonds
      structure.topology.guess_names
      structure.residues.join(&.code).should eq expected
    end

    it "guesses the topology of a phospholipid" do
      Chem::Templates.load spec_file("dmpe.mol2")
      structure = load_file "dmpe.xyz"
      structure.topology.guess_bonds
      structure.topology.guess_names
      structure.residues.size.should eq 1
      structure.residues[0].name.should eq "DMP"
    end
  end

  describe "#guess_unknown_residue_types" do
    it "guesses type of unknown residue when previous is known" do
      top = load_file("residue_type_unknown_previous.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues[1].protein?.should be_true
    end

    it "guesses type of unknown residue when next is known" do
      top = load_file("residue_type_unknown_next.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues[0].protein?.should be_true
    end

    it "guesses type of unknown residue when its flanked by known residues" do
      top = load_file("residue_type_unknown_flanked.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues[1].protein?.should be_true
    end

    it "does not guess type of unknown residue" do
      top = load_file("residue_type_unknown_single.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues[0].other?.should be_true
    end

    it "does not guess type of unknown residue when its not connected to others" do
      top = load_file("residue_type_unknown_next_gap.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues.first.other?.should be_true
    end

    it "does not guess type of unknown residue when it's not bonded by link bond" do
      top = load_file("residue_type_unknown_covalent_ligand.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues.map(&.type.to_s).should eq %w(Protein Protein Protein Other)
    end

    it "guess type of unknown residue with non-standard atom names" do
      top = load_file("residue_unknown_non_standard_names.pdb").topology
      top.guess_bonds
      top.guess_unknown_residue_types
      top.residues.all?(&.protein?).should be_true
    end
  end

  describe "#apply_templates" do
    it "assigns bonds, formal charges, and residue templates" do
      structure = fake_structure(include_bonds: false)
      structure.topology.apply_templates

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
      structure.topology.apply_templates

      r1, r2, r3, r4 = structure.residues
      r1["C"].bonds[r2["N"]]?.should_not be_nil
      r2["C"].bonds[r3["N"]]?.should be_nil
      r3["C"].bonds[r4["N"]]?.should_not be_nil
    end
  end

  describe "#guess_formal_charges" do
    it "works for methane" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0.00000, 0.00000, 0.00000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, -0.51380, 0.89000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, 1.02770, 0.00000)
        atom Chem::PeriodicTable::H, vec3(-0.36330, -0.51380, -0.89000)
        atom Chem::PeriodicTable::H, vec3(1.09000, 0.00000, 0.00000)
        bond 1, 2
        bond 1, 3
        bond 1, 4
        bond 1, 5
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0]
    end

    it "works for ammonia" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::N, vec3(-2.10870, 1.82800, 0.04300)
        atom Chem::PeriodicTable::H, vec3(-1.24270, 1.97310, 0.54230)
        atom Chem::PeriodicTable::H, vec3(-2.70480, 2.63480, 0.16060)
        atom Chem::PeriodicTable::H, vec3(-2.57490, 1.00960, 0.40750)
        bond 1, 2
        bond 1, 3
        bond 1, 4
      end
      structure.topology.guess_formal_charges

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
        bond 1, 2
        bond 1, 3
        bond 1, 4
        bond 1, 5
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1, 0, 0, 0, 0]
    end

    it "works for cyanide" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
        atom Chem::PeriodicTable::N, vec3(1.16, 0, 0)
        bond 1, 2, :triple
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1, 0]
    end

    it "works for ozone" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::O, vec3(-0.97960, 1.34290, 0.19110)
        atom Chem::PeriodicTable::O, vec3(-0.18710, 0.62720, -0.20810)
        atom Chem::PeriodicTable::O, vec3(0.47750, 0.03050, 0.50030)
        bond 1, 2, :single
        bond 2, 3, :double
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [-1, 1, 0]
    end

    it "works for divalent sulfur (SF2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.46830, 1.15280, -0.38900)
        atom Chem::PeriodicTable::F, vec3(-1.04840, 1.50510, 0.71990)
        atom Chem::PeriodicTable::F, vec3(-1.15490, 0.56490, -1.32330)
        bond 1, 2
        bond 1, 3
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0]
    end

    it "works for divalent sulfur (SO2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.25380, -0.14690, 0.13990)
        atom Chem::PeriodicTable::O, vec3(0.49180, -1.10210, -0.75260)
        atom Chem::PeriodicTable::O, vec3(-0.99950, 0.80830, 1.03240)
        bond 1, 2, :double
        bond 1, 3, :double
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0]
    end

    it "works for divalent sulfur (SO2+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::S, vec3(-0.78990, 1.25770, -1.15060)
        atom Chem::PeriodicTable::O, vec3(-0.92360, 0.95430, 0.30200)
        atom Chem::PeriodicTable::O, vec3(-0.31430, -0.07080, -1.67910)
        bond 1, 2
        bond 1, 3, :double
      end
      structure.topology.guess_formal_charges

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
        bond 1, 2
        bond 1, 3, :double
        bond 1, 4
        bond 1, 5, :double
      end
      structure.topology.guess_formal_charges

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
        bond 1, 2
        bond 1, 3
        bond 1, 4
        bond 1, 5
        bond 1, 6
        bond 1, 7
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0, 0]
    end

    it "works for divalent phosphorus (PO2)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(-2.21100, -0.48150, -2.72450)
        atom Chem::PeriodicTable::O, vec3(-2.50240, -2.12750, -2.57730)
        atom Chem::PeriodicTable::O, vec3(-0.63530, -0.52300, -2.09580)
        bond 1, 2
        bond 1, 3, :double
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [0, -1, 0]
    end

    it "works for tetravalent phosphorus (PO4)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::P, vec3(0.0000, -0.0001, 0.0000)
        atom Chem::PeriodicTable::O, vec3(1.5234, -0.0688, -0.1977)
        atom Chem::PeriodicTable::O, vec3(-0.6406, 0.7180, -1.1991)
        atom Chem::PeriodicTable::O, vec3(-0.5679, -1.4248, 0.1073)
        atom Chem::PeriodicTable::O, vec3(-0.3149, 0.7757, 1.2895)
        bond 1, 2, :double
        bond 1, 3
        bond 1, 4
        bond 1, 5
      end
      structure.topology.guess_formal_charges

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
        bond 1, 2
        bond 1, 3
        bond 1, 4
        bond 1, 5
        bond 1, 6
      end
      structure.topology.guess_formal_charges

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
        bond 1, 2
        bond 1, 3
        bond 1, 4
        bond 1, 5
        bond 1, 6
        bond 1, 7
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1, 0, 0, 0, 0, 0, 0]
    end

    it "works for monoatomic cations (K+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::K, vec3(0, 0, 0)
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1]
    end

    it "works for monoatomic cations (Mg2+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Mg, vec3(0, 0, 0)
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq 2
      structure.atoms.map(&.formal_charge).should eq [2]
    end

    it "works for monoatomic anions" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Cl, vec3(0, 0, 0)
      end
      structure.topology.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1]
    end
  end

  describe "#renumber_residues_by" do
    it "renumbers residues by the given order" do
      top = load_file("3sgr.pdb").topology
      expected = top.chains.map { |chain| chain.residues.sort_by(&.code) }
      top.renumber_residues_by(&.code)
      top.chains.map(&.residues).should eq expected
    end
  end

  describe "#renumber_residues_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file("5e5v--unwrapped.poscar", guess_bonds: true, guess_names: true)
      top = structure.topology
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

      chains[0].residues[0].pred?.should be_nil
      chains[0].residues[3].pred?.try(&.name).should eq "GLY"
      chains[0].residues[3].succ?.try(&.name).should eq "ILE"
      chains[0].residues[-1].succ?.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      top = load_file("hlx_gly.poscar").topology
      top.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.succ?.should eq b
        b.pred?.should eq a
      end
    end

    it "does not depend on current residue numbering (#82)" do
      [
        "polyala-trp--theta-80.000--c-19.91.poscar",
        "polyala-trp--theta-180.000--c-10.00.poscar",
      ].each do |filename|
        top = load_file(filename, guess_bonds: true, guess_names: true).topology
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

  describe "#bonds" do
    it "returns the bonds" do
      top = load_file("benzene.mol2").topology
      top.bonds.map(&.atoms.map(&.serial)).sort!.should eq [
        {1, 2}, {1, 6}, {1, 7}, {2, 3}, {2, 8}, {3, 4}, {3, 9}, {4, 5},
        {4, 10}, {5, 6}, {5, 11}, {6, 12},
      ]
    end
  end

  describe "#guess_angles" do
    it "computes the angles" do
      top = load_file("8FX.mol2").topology
      top.guess_angles
      top.angles.map(&.atoms.map(&.serial)).sort!.should eq [
        {1, 2, 3}, {1, 2, 23}, {1, 28, 27}, {1, 28, 29}, {2, 1, 28}, {2, 1, 30},
        {2, 3, 4}, {2, 3, 31}, {3, 2, 23}, {3, 4, 29}, {3, 4, 32}, {4, 3, 31},
        {4, 29, 24}, {4, 29, 28}, {5, 6, 7}, {5, 6, 33}, {5, 15, 27},
        {5, 15, 45}, {5, 17, 16}, {6, 5, 15}, {6, 5, 17}, {6, 7, 8}, {6, 7, 16},
        {7, 6, 33}, {7, 8, 21}, {7, 8, 22}, {7, 8, 34}, {7, 16, 17},
        {7, 16, 46}, {8, 7, 16}, {8, 21, 22}, {8, 21, 48}, {8, 21, 49},
        {8, 22, 21}, {8, 22, 50}, {8, 22, 51}, {9, 18, 10}, {9, 18, 13},
        {9, 25, 24}, {9, 25, 26}, {10, 11, 14}, {10, 11, 19}, {10, 11, 37},
        {10, 18, 13}, {11, 10, 18}, {11, 10, 35}, {11, 10, 36}, {11, 14, 42},
        {11, 14, 43}, {11, 14, 44}, {11, 19, 12}, {11, 19, 47}, {12, 13, 18},
        {12, 13, 40}, {12, 13, 41}, {12, 19, 47}, {13, 12, 19}, {13, 12, 38},
        {13, 12, 39}, {14, 11, 19}, {14, 11, 37}, {15, 5, 17}, {15, 27, 26},
        {15, 27, 28}, {17, 16, 46}, {18, 9, 20}, {18, 9, 25}, {18, 10, 35},
        {18, 10, 36}, {18, 13, 40}, {18, 13, 41}, {19, 11, 37}, {19, 12, 38},
        {19, 12, 39}, {20, 9, 25}, {21, 8, 22}, {21, 8, 34}, {21, 22, 50},
        {21, 22, 51}, {22, 8, 34}, {22, 21, 48}, {22, 21, 49}, {24, 25, 26},
        {24, 29, 28}, {25, 24, 29}, {25, 26, 27}, {26, 27, 28}, {27, 15, 45},
        {27, 28, 29}, {28, 1, 30}, {29, 4, 32}, {35, 10, 36}, {38, 12, 39},
        {40, 13, 41}, {42, 14, 43}, {42, 14, 44}, {43, 14, 44}, {48, 21, 49},
        {50, 22, 51},
      ]
    end
  end

  describe "#guess_dihedrals" do
    it "computes the dihedrals" do
      top = load_file("8FX.mol2").topology
      top.guess_dihedrals
      top.dihedrals.map(&.atoms.map(&.serial)).sort!.should eq [
        {1, 2, 3, 4}, {1, 2, 3, 31}, {1, 28, 29, 4}, {1, 28, 29, 24},
        {2, 1, 28, 27}, {2, 1, 28, 29}, {2, 3, 4, 29}, {2, 3, 4, 32},
        {3, 2, 1, 28}, {3, 2, 1, 30}, {3, 4, 29, 24}, {3, 4, 29, 28},
        {4, 3, 2, 23}, {5, 6, 7, 8}, {5, 6, 7, 16}, {5, 15, 27, 26},
        {5, 15, 27, 28}, {5, 17, 16, 46}, {6, 5, 15, 27}, {6, 5, 15, 45},
        {6, 5, 17, 16}, {6, 7, 8, 21}, {6, 7, 8, 22}, {6, 7, 8, 34},
        {6, 7, 16, 17}, {6, 7, 16, 46}, {7, 6, 5, 15}, {7, 6, 5, 17},
        {7, 8, 21, 22}, {7, 8, 21, 48}, {7, 8, 21, 49}, {7, 8, 22, 21},
        {7, 8, 22, 50}, {7, 8, 22, 51}, {7, 16, 17, 5}, {8, 7, 6, 33},
        {8, 7, 16, 17}, {8, 7, 16, 46}, {8, 21, 22, 50}, {8, 21, 22, 51},
        {8, 22, 21, 48}, {8, 22, 21, 49}, {9, 18, 10, 35}, {9, 18, 10, 36},
        {9, 18, 13, 40}, {9, 18, 13, 41}, {9, 25, 24, 29}, {9, 25, 26, 27},
        {10, 11, 14, 42}, {10, 11, 14, 43}, {10, 11, 14, 44}, {10, 11, 19, 12},
        {10, 11, 19, 47}, {10, 18, 9, 20}, {10, 18, 9, 25}, {10, 18, 13, 40},
        {10, 18, 13, 41}, {11, 10, 18, 9}, {11, 10, 18, 13}, {11, 19, 12, 38},
        {11, 19, 12, 39}, {12, 13, 18, 9}, {12, 13, 18, 10}, {12, 19, 11, 37},
        {13, 12, 19, 11}, {13, 12, 19, 47}, {13, 18, 9, 20}, {13, 18, 9, 25},
        {13, 18, 10, 35}, {13, 18, 10, 36}, {14, 11, 10, 18}, {14, 11, 10, 35},
        {14, 11, 10, 36}, {14, 11, 19, 12}, {14, 11, 19, 47}, {15, 5, 6, 33},
        {15, 5, 17, 16}, {15, 27, 28, 1}, {15, 27, 28, 29}, {16, 7, 6, 33},
        {16, 7, 8, 21}, {16, 7, 8, 22}, {16, 7, 8, 34}, {17, 5, 6, 33},
        {17, 5, 15, 27}, {17, 5, 15, 45}, {18, 9, 25, 24}, {18, 9, 25, 26},
        {18, 10, 11, 19}, {18, 10, 11, 37}, {18, 13, 12, 19}, {18, 13, 12, 38},
        {18, 13, 12, 39}, {19, 11, 10, 35}, {19, 11, 10, 36}, {19, 11, 14, 42},
        {19, 11, 14, 43}, {19, 11, 14, 44}, {19, 12, 13, 40}, {19, 12, 13, 41},
        {20, 9, 25, 24}, {20, 9, 25, 26}, {21, 8, 22, 50}, {21, 8, 22, 51},
        {21, 22, 8, 34}, {22, 8, 21, 48}, {22, 8, 21, 49}, {22, 21, 8, 34},
        {23, 2, 1, 28}, {23, 2, 1, 30}, {23, 2, 3, 31}, {24, 25, 26, 27},
        {24, 29, 4, 32}, {25, 24, 29, 4}, {25, 24, 29, 28}, {25, 26, 27, 15},
        {25, 26, 27, 28}, {26, 25, 24, 29}, {26, 27, 15, 45}, {26, 27, 28, 1},
        {26, 27, 28, 29}, {27, 28, 1, 30}, {27, 28, 29, 4}, {27, 28, 29, 24},
        {28, 27, 15, 45}, {28, 29, 4, 32}, {29, 4, 3, 31}, {29, 28, 1, 30},
        {31, 3, 4, 32}, {34, 8, 21, 48}, {34, 8, 21, 49}, {34, 8, 22, 50},
        {34, 8, 22, 51}, {35, 10, 11, 37}, {36, 10, 11, 37}, {37, 11, 14, 42},
        {37, 11, 14, 43}, {37, 11, 14, 44}, {37, 11, 19, 47}, {38, 12, 13, 40},
        {38, 12, 13, 41}, {38, 12, 19, 47}, {39, 12, 13, 40}, {39, 12, 13, 41},
        {39, 12, 19, 47}, {48, 21, 22, 50}, {48, 21, 22, 51}, {49, 21, 22, 50},
        {49, 21, 22, 51},
      ]
    end
  end

  describe "#guess_impropers" do
    it "returns the impropers" do
      top = load_file("8FX.mol2").topology
      top.guess_impropers
      top.impropers.map(&.atoms.map(&.serial)).sort!.should eq [
        {1, 2, 3, 23}, {1, 28, 27, 29}, {2, 1, 28, 30}, {2, 3, 4, 31},
        {3, 4, 29, 32}, {4, 29, 24, 28}, {5, 6, 7, 33}, {5, 15, 27, 45},
        {6, 5, 15, 17}, {6, 7, 8, 16}, {7, 8, 21, 22}, {7, 8, 21, 34},
        {7, 8, 22, 34}, {7, 16, 17, 46}, {8, 21, 22, 48}, {8, 21, 22, 49},
        {8, 21, 48, 49}, {8, 22, 21, 50}, {8, 22, 21, 51}, {8, 22, 50, 51},
        {9, 18, 10, 13}, {9, 25, 24, 26}, {10, 11, 14, 19}, {10, 11, 14, 37},
        {10, 11, 19, 37}, {11, 10, 18, 35}, {11, 10, 18, 36}, {11, 10, 35, 36},
        {11, 14, 42, 43}, {11, 14, 42, 44}, {11, 14, 43, 44}, {11, 19, 12, 47},
        {12, 13, 18, 40}, {12, 13, 18, 41}, {12, 13, 40, 41}, {13, 12, 19, 38},
        {13, 12, 19, 39}, {13, 12, 38, 39}, {14, 11, 19, 37}, {15, 27, 26, 28},
        {18, 9, 20, 25}, {18, 10, 35, 36}, {18, 13, 40, 41}, {19, 12, 38, 39},
        {21, 8, 22, 34}, {21, 22, 50, 51}, {22, 21, 48, 49}, {42, 14, 43, 44},
      ]
    end
  end

  describe ".guess_element" do
    it "raises if unknown" do
      expect_raises(Chem::Error, "Could not guess element of X1") do
        Chem::Topology.guess_element("X1")
      end
    end
  end

  describe ".guess_element?" do
    it "returns the element by atom name" do
      # TODO: test different atom names (#116)
      Chem::Topology.guess_element?("O").should be Chem::PeriodicTable::O
      Chem::Topology.guess_element?("CA").should be Chem::PeriodicTable::C
    end

    it "returns nil if unknown" do
      Chem::Topology.guess_element?("X1").should be_nil
    end
  end
end
