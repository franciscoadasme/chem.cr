require "../spec_helper"

describe Topology::Perception do
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
        structure.atoms[i].valency.should eq 1
        structure.atoms[i].bonds.size.should eq 0
        structure.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      structure.atoms[324].valency.should eq 3
      structure.atoms[324].bonds.size.should eq 4
      structure.atoms[324].formal_charge.should eq 1

      # c-ter
      structure.atoms[364].valency.should eq 2
      structure.atoms[364].formal_charge.should eq -1
      structure.atoms[365].valency.should eq 2
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

      structure.atoms[13].valency.should eq 2
      structure.atoms[13].bonded_atoms.map(&.serial).sort!.should eq [13, 26]
      structure.atoms[14].valency.should eq 2
      structure.atoms[14].bonded_atoms.map(&.serial).should eq [13]

      # sulfate ion
      structure.atoms[3].valency.should eq 6
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

      structure.atoms[15].valency.should eq 2
      structure.atoms[15].bonded_atoms.map(&.serial).should eq [15, 21]
      structure.atoms[15].bonds[structure.atoms[14]].single?.should be_true
      structure.atoms[15].bonds[structure.atoms[20]].single?.should be_true

      structure.atoms[37].valency.should eq 2
      structure.atoms[37].bonded_atoms.map(&.serial).should eq [37, 39]
      structure.atoms[37].bonds[structure.atoms[36]].single?.should be_true
      structure.atoms[37].bonds[structure.atoms[38]].single?.should be_true
    end

    pending "guess bond orders if hydrogens are missing" do
      structure = load_file "residue_kind_unknown_covalent_ligand.pdb"
    end

    pending "guess bond orders if hydrogens are missing" do
      structure = load_file "1crn.xyz"
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
      Chem::Topology::Perception.new(structure).guess_residues
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
    end

    it "assigns bond orders for a structure without hydrogens" do
      structure = Chem::Structure.build do
        residue "ICN" do
          atom :i, V[3.149, 0, 0]
          atom :c, V[1.148, 0, 0]
          atom :n, V[0, 0, 0]
          # bond "I1", "C1"
          # bond "C1", "N1", order: 3
        end
      end
      structure.bonds.size.should eq 2
      structure.dig('A', 1, "I1").bonds[structure.dig('A', 1, "C1")].order.should eq 1
      structure.dig('A', 1, "C1").bonds[structure.dig('A', 1, "N1")].order.should eq 3
    end
  end
end
