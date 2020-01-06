require "../spec_helper"

describe Chem::Structure::Builder do
  it "builds a structure" do
    st = Chem::Structure::Builder.build do
      title "Ser-Thr-Gly Val"
      chain 'F' do
        residue "SER", 1 do
          atom "N", V[10.761, 7.798, 14.008]
          atom "CA", V[11.332, 7.135, 15.151]
          atom "C", V[10.293, 6.883, 16.240]
          atom "O", V[9.831, 7.812, 16.932]
          atom "CB", V[12.486, 8.009, 15.664]
          atom "OG", V[12.863, 7.872, 17.046]
        end
        residue "THR", 2 do
          atom "N", V[9.905, 5.621, 16.468]
          atom "CA", V[8.911, 5.306, 17.473]
          atom "C", V[9.309, 5.682, 18.870]
          atom "O", V[8.414, 5.905, 19.663]
          atom "CB", V[8.583, 3.831, 17.460]
          atom "OG1", V[9.767, 3.088, 17.284]
          atom "CG2", V[7.681, 3.521, 16.314]
        end
        residue "GLY", 3 do
          atom "N", V[10.580, 5.793, 19.220]
          atom "CA", V[10.958, 6.188, 20.552]
          atom "C", V[10.749, 7.689, 20.740]
          atom "O", V[10.201, 8.174, 21.744]
        end
      end
      chain 'G' do
        residue "VAL", 1 do
          atom "N", V[18.066, -7.542, 27.177]
          atom "CA", V[17.445, -8.859, 27.179]
          atom "C", V[16.229, -8.870, 26.253]
          atom "O", V[16.058, -9.815, 25.479]
          atom "CB", V[17.045, -9.235, 28.617]
          atom "CG1", V[16.407, -10.621, 28.678]
          atom "CG2", V[18.300, -9.262, 29.461]
        end
      end
    end

    st.title.should eq "Ser-Thr-Gly Val"

    st.n_chains.should eq 2
    st.chains.map(&.id).should eq ['F', 'G']

    st.n_residues.should eq 4
    st.residues.map(&.chain.id).should eq ['F', 'F', 'F', 'G']
    st.residues.map(&.number).should eq [1, 2, 3, 1]
    st.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    st.residues.map(&.n_atoms).should eq [6, 7, 4, 7]

    st.n_atoms.should eq 24
    st.atoms.map(&.serial).should eq (1..24).to_a
    st.atoms[0..6].map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG", "N"]
    st.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    st.atoms.map(&.chain.id).should eq ("F" * 17 + "G" * 7).chars
    st.atoms[serial: 13].x.should eq 7.681
  end

  it "builds a structure (no DSL)" do
    builder = Chem::Structure::Builder.new
    builder.title "Ser-Thr-Gly Val"
    builder.chain 'T'
    builder.residue "SER"
    builder.atom "N", V[10.761, 7.798, 14.008]
    builder.residue "THR"
    builder.atom "N", V[9.905, 5.621, 16.468]
    builder.residue "GLY"
    builder.atom "N", V[10.580, 5.793, 19.220]
    builder.chain 'U'
    builder.residue "VAL"
    builder.atom "N", V[18.066, -7.542, 27.177]

    st = builder.build

    st.title.should eq "Ser-Thr-Gly Val"
    st.chains.map(&.id).should eq ['T', 'U']
    st.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    st.residues.map(&.number).should eq [1, 2, 3, 1]
    st.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    st.atoms[serial: 4].x.should eq 18.066
  end

  it "builds a structure with lattice" do
    st = Chem::Structure::Builder.build do
      lattice V[25, 32, 12], V[12, 34, 23], V[12, 68, 21]
    end

    lat = st.lattice.not_nil!
    lat.i.should eq Vector[25, 32, 12]
    lat.j.should eq Vector[12, 34, 23]
    lat.k.should eq Vector[12, 68, 21]
  end

  it "builds a structure with lattice using numbers" do
    st = Chem::Structure::Builder.build do
      lattice 25, 34, 21
    end

    lat = st.lattice.not_nil!
    lat.i.should eq Vector[25, 0, 0]
    lat.j.should eq Vector[0, 34, 0]
    lat.k.should eq Vector[0, 0, 21]
  end

  it "builds a structure with lattice using numbers (one-line)" do
    st = Chem::Structure::Builder.build do
      lattice 25, 34, 21
    end

    lat = st.lattice.not_nil!
    lat.i.should eq Vector[25, 0, 0]
    lat.j.should eq Vector[0, 34, 0]
    lat.k.should eq Vector[0, 0, 21]
  end

  it "names chains automatically" do
    st = Chem::Structure::Builder.build do
      62.times do
        chain { }
      end
    end

    ids = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".chars
    st.chains.map(&.id).should eq ids
  end

  it "names chains automatically after manually setting one" do
    st = Chem::Structure::Builder.build do
      chain 'F'
      chain { }
      chain { }
    end

    st.chains.map(&.id).should eq ['F', 'G', 'H']
  end

  it "fails over chain id limit" do
    expect_raises ArgumentError, "Non-alphanumeric chain id" do
      Chem::Structure::Builder.build do
        63.times do
          chain { }
        end
      end
    end
  end

  it "numbers residues automatically" do
    st = Chem::Structure::Builder.build do
      chain do
        2.times { residue "ALA" }
      end
      chain do
        5.times { residue "GLY" }
      end
      chain do
        3.times { residue "PRO" }
      end
    end

    st.residues.map(&.number).should eq [1, 2, 1, 2, 3, 4, 5, 1, 2, 3]
  end

  it "numbers residues automatically after manually setting one" do
    st = Chem::Structure::Builder.build do
      chain
      residue "SER", 5
      3.times { residue "ALA" }
    end

    st.residues.map(&.number).should eq [5, 6, 7, 8]
  end

  it "names atoms automatically when called with element" do
    st = Chem::Structure::Builder.build do
      atom :C, Vector.origin
      atom :C, Vector.origin
      atom :O, Vector.origin
      atom :N, Vector.origin
      atom :C, Vector.origin
      atom :N, Vector.origin
    end

    st.atoms.map(&.name).should eq ["C1", "C2", "O1", "N1", "C3", "N2"]
  end

  it "creates a chain automatically" do
    st = Chem::Structure::Builder.build do
      residue "SER"
    end

    st.chains.map(&.id).should eq ['A']
  end

  it "creates a residue automatically" do
    st = Chem::Structure::Builder.build do
      atom "CA", Vector.origin
    end

    st.chains.map(&.id).should eq ['A']
    st.residues.map(&.number).should eq [1]
    st.residues.map(&.name).should eq ["UNK"]
  end

  it "adds dummy atoms" do
    st = Chem::Structure::Builder.build do
      %w(N CA C O CB).each { |name| atom name, Vector.origin }
    end

    st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    st.atoms.all?(&.coords.zero?).should be_true
  end

  it "adds dummy atoms with coordinates" do
    st = Chem::Structure::Builder.build do
      atom V[1, 0, 0]
      atom V[2, 0, 0]
    end

    st.atoms.map(&.name).should eq ["C1", "C2"]
    st.atoms.map(&.x).should eq [1, 2]
  end

  it "adds atom with named arguments" do
    st = Chem::Structure::Builder.build do
      atom "OD1", Vector.origin, formal_charge: -1, temperature_factor: 43.24
    end

    atom = st.atoms[-1]
    atom.formal_charge.should eq -1
    atom.temperature_factor.should eq 43.24
  end

  it "adds bonds by atom index" do
    structure = Chem::Structure.build do
      atom :O, V[0, 0, 0]
      atom :H, V[-1, 0, 0]
      atom :H, V[1, 0, 0]

      bond 0, 1
      bond 0, 2
    end

    expected = [{"O1", "H1"}, {"O1", "H2"}]
    structure.bonds.map { |bond| {bond[0].name, bond[1].name} }.should eq expected
  end

  it "sets secondary structure" do
    structure = Chem::Structure.build do
      chain { %w(PHE ARG ALA).each { |name| residue name } }
      chain { %w(ILE VAL).each { |name| residue name } }
      secondary_structure({'A', 1, nil}, {'A', 2, nil}, :helix_alpha)
      secondary_structure({'B', 2, nil}, {'B', 2, nil}, :beta_strand)
    end

    structure.each_residue.map(&.dssp).to_a.should eq ['H', 'H', '0', '0', 'E']
  end

  describe "#assign_topology_from_templates" do
    it "assigns bonds and types based on templates" do
      st = fake_structure
      r1, r2, r3 = st.residues

      Chem::Structure::Builder.build(st) { assign_topology_from_templates }

      [r1, r2, r3].map(&.protein?).should eq [true, true, true]
      [r1, r2, r3].map(&.formal_charge).should eq [-1, 0, 0]

      r1["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r1["N"].bonds[r1["CA"]].order.should eq 1
      r1["CA"].bonds[r1["C"]].order.should eq 1
      r1["C"].bonds[r1["O"]].order.should eq 2
      r1["CA"].bonds[r1["CB"]].order.should eq 1
      r1["CB"].bonds[r1["CG"]].order.should eq 1
      r1["CG"].bonds[r1["OD1"]].order.should eq 2
      r1["CG"].bonds[r1["OD2"]].order.should eq 1

      r1["C"].bonded_atoms.map(&.name).should eq ["CA", "O", "N"]
      r2["N"].bonded_atoms.map(&.name).should eq ["C", "CA"]

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
      st = Chem::Structure.read "spec/data/pdb/protein_gap.pdb"
      r1, r2, r3, r4 = st.residues

      Chem::Structure::Builder.build(st) { assign_topology_from_templates }

      r1["C"].bonds[r2["N"]]?.should_not be_nil
      r2["C"].bonds[r3["N"]]?.should be_nil
      r3["C"].bonds[r4["N"]]?.should_not be_nil
    end

    it "guess kind of unknown residue when previous is known" do
      st = Chem::Structure.read "spec/data/pdb/residue_kind_unknown_previous.pdb"
      Chem::Structure::Builder.build(st) { assign_topology_from_templates }
      st.residues[1].protein?.should be_true
    end

    it "guess kind of unknown residue when next is known" do
      st = Chem::Structure.read "spec/data/pdb/residue_kind_unknown_next.pdb"
      Chem::Structure::Builder.build(st) { assign_topology_from_templates }
      st.residues[0].protein?.should be_true
    end

    it "guess kind of unknown residue when its flanked by known residues" do
      st = Chem::Structure.read "spec/data/pdb/residue_kind_unknown_flanked.pdb"
      Chem::Structure::Builder.build(st) { assign_topology_from_templates }
      st.residues[1].protein?.should be_true
    end

    it "does not guess kind of unknown residue" do
      st = Chem::Structure.read "spec/data/pdb/residue_kind_unknown_single.pdb"
      Chem::Structure::Builder.build(st) { assign_topology_from_templates }
      st.residues[0].other?.should be_true
    end

    it "does not guess kind of unknown residue when its not connected to others" do
      st = Chem::Structure.read "spec/data/pdb/residue_kind_unknown_next_gap.pdb"
      Chem::Structure::Builder.build(st) { assign_topology_from_templates }
      st.residues.first.other?.should be_true
    end

    it "does not guess kind of unknown residue when it's not bonded by link bond" do
      structure = Structure.read "spec/data/pdb/residue_kind_unknown_covalent_ligand.pdb"
      Chem::Structure::Builder.build(structure) do
        guess_bonds_from_geometry
        assign_topology_from_templates
      end
      structure.residues.map(&.kind.to_s).should eq %w(Protein Protein Protein Other)
    end
  end

  describe "#guess_bonds_from_geometry" do
    it "guesses bonds from geometry" do
      structure = Chem::Structure.read "spec/data/poscar/AlaIle--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry

      atoms = structure.atoms
      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      atoms.each_with_index { |atom, i| atom.bonds.size.should eq n_bonds[i] }
      atoms[0].bonded_atoms.map(&.serial).sort!.should eq [2, 14, 15, 16]
      atoms[4].bonded_atoms.map(&.serial).sort!.should eq [4, 28, 30]
      atoms[4].bonds[atoms[27]].order.should eq 2
      atoms[4].bonds[atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      structure = Chem::Structure.read "spec/data/xyz/k2p_pore_b.xyz"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry

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
      structure.atoms[427].bonds[structure.atoms[428]].order.should eq 2
      structure.atoms[428].bonds[structure.atoms[430]].order.should eq 1
      structure.atoms[430].bonds[structure.atoms[432]].order.should eq 2
      structure.atoms[432].bonds[structure.atoms[431]].order.should eq 1
      structure.atoms[431].bonds[structure.atoms[429]].order.should eq 2
      structure.atoms[429].bonds[structure.atoms[427]].order.should eq 1
    end

    it "guesses bonds from geometry having a sulfate ion" do
      structure = Chem::Structure.read "spec/data/xyz/sulbactam.xyz"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry

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
      structure = Chem::Structure.read "spec/data/xyz/acama.xyz"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry

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
  end

  describe "#guess_topology_from_connectivity" do
    it "guesses the topology of a dipeptide" do
      structure = Chem::Structure.read "spec/data/poscar/AlaIle--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq %w(ALA ILE)
      structure.residues.map(&.number).should eq [1, 2]
      structure.residues[0].atoms.map(&.name).should eq %w(
        N CA HA C O CB HB1 HB2 HB3 H1 H2)
      structure.residues[1].atoms.map(&.name).should eq %w(
        N H CA HA C O CB HB CG1 HG11 HG12 CD HD1 HD2 HD3 CG2 HG21 HG22 HG23 OXT HXT)
    end

    it "guesses the topology of two peptide chains" do
      structure = Chem::Structure.read "spec/data/poscar/5e61--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      structure.chains.map(&.id).should eq ['A', 'B']
      structure.each_chain do |chain|
        chain.residues.map(&.name).should eq %w(PHE GLY ALA ILE LEU SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues[0].atoms.map(&.name).should eq %w(
          N CA HA C O CB HB1 HB2 CG CD1 HD1 CE1 HE1 CZ HZ CE2 HE2 CD2 HD2 H1 H2)
        chain.residues[5].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG)
        chain.residues[6].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG OXT HXT)
      end
    end

    it "guesses the topology of two peptides off-center (issue #3)" do
      structure = Chem::Structure.read "spec/data/poscar/5e61--off-center.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      chains = structure.chains
      chains.map(&.id).should eq ['A', 'B']
      chains[0].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
    end

    it "guesses the topology of a broken peptide with waters" do
      structure = Chem::Structure.read "spec/data/poscar/5e5v--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      chains = structure.chains
      chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      chains[0].residues.map(&.name).sort!.should eq %w(ALA ASN GLY ILE LEU PHE SER)
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER UNK)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]
    end

    it "guesses the topology of a periodic peptide" do
      structure = Chem::Structure.read "spec/data/poscar/hlx_gly.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      structure.chains.map(&.id).should eq ['A']
      structure.chains[0].residues.map(&.name).should eq ["GLY"] * 13
      structure.chains[0].residues.map(&.number).should eq (1..13).to_a
    end

    it "guesses the topology of many fragments (beyond max chain id)" do
      structure = Chem::Structure.read "spec/data/poscar/many_fragments.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity

      structure.n_chains.should eq 1
      structure.n_residues.should eq 144
      structure.fragments.size.should eq 72
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq ["PHE"] * 144
      structure.residues.map(&.number).should eq (1..144).to_a
    end

    it "fails when structure has no bonds" do
      expect_raises Chem::Error, "Structure has no bonds" do
        structure = Chem::Structure.read "spec/data/poscar/5e5v--unwrapped.poscar"
        builder = Chem::Structure::Builder.new structure
        builder.guess_topology_from_connectivity
      end
    end
  end

  describe "#renumber_by_connectivity" do
    it "renumber residues in ascending order based on the link bond" do
      structure = Chem::Structure.read "spec/data/poscar/5e5v--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity
      builder.renumber_by_connectivity

      chains = structure.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].previous.should be_nil
      chains[0].residues[3].previous.try(&.name).should eq "GLY"
      chains[0].residues[3].next.try(&.name).should eq "ILE"
      chains[0].residues[-1].next.should be_nil
    end

    it "renumber residues of a periodic peptide" do
      structure = Chem::Structure.read "spec/data/poscar/hlx_gly.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      builder.guess_topology_from_connectivity
      builder.renumber_by_connectivity

      structure.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.next.should eq b
        b.previous.should eq a
      end
    end
  end
end
