require "../spec_helper"

describe Chem::Structure do
  describe ".build" do
    it "builds a structure" do
      st = Chem::Structure.build do
        title "Alanine"
        residue "ALA" do
          %w(N CA C O CB).each { |name| atom name, vec3(0, 0, 0) }
        end
      end

      st.title.should eq "Alanine"
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    end
  end

  describe "#clone" do
    it "returns a copy of the structure" do
      structure = load_file "1crn.pdb", guess_bonds: true
      other = structure.clone

      other.should_not be structure
      other.dig('A').should_not be structure.dig('A')
      other.dig('A', 32).should_not be structure.dig('A', 32)
      other.dig('A', 13, "CA").should_not be structure.dig('A', 13, "CA")

      other.chains.size.should eq 1
      other.residues.size.should eq 46
      other.atoms.size.should eq 327
      other.bonds.size.should eq 337
      other.chains.map(&.id).should eq ['A']
      other.dig('A', 32).name.should eq "CYS"
      other.dig('A', 32).sec.beta_strand?.should be_true
      other.dig('A', 32, "CA").coords.should eq [8.140, 11.694, 9.635]

      other.cell?.should eq structure.cell?
      other.experiment.should eq structure.experiment
      other.title.should eq structure.title
    end
  end

  describe "#periodic?" do
    it "returns true when a structure has a cell" do
      structure = Chem::Structure.new
      structure.cell = Chem::Spatial::Parallelepiped.new({10, 20, 30})
      structure.periodic?.should be_true
    end

    it "returns false when a structure does not have a cell" do
      Chem::Structure.new.periodic?.should be_false
    end
  end

  describe "#write" do
    structure = Chem::Structure.build do
      title "ICN"
      cell 5, 10, 10
      atom :I, vec3(-2, 0, 0)
      atom :C, vec3(0, 0, 0)
      atom :N, vec3(1.5, 0, 0)
    end

    it "writes a structure into a file" do
      path = File.tempname ".xyz"
      structure.write path
      File.read(path).should eq <<-EOS
        3
        ICN
        I    -2.000    0.000    0.000
        C     0.000    0.000    0.000
        N     1.500    0.000    0.000

        EOS
      File.delete path
    end

    it "writes a structure into a file without extension" do
      path = File.tempname "POSCAR", ""
      structure.write path
      File.read(path).should eq <<-EOS
        ICN
           1.00000000000000
             5.0000000000000000    0.0000000000000000    0.0000000000000000
             0.0000000000000000   10.0000000000000000    0.0000000000000000
             0.0000000000000000    0.0000000000000000   10.0000000000000000
           I    C    N 
             1     1     1
        Cartesian
           -2.0000000000000000    0.0000000000000000    0.0000000000000000
            0.0000000000000000    0.0000000000000000    0.0000000000000000
            1.5000000000000000    0.0000000000000000    0.0000000000000000\n
        EOS
      File.delete path
    end

    it "writes a structure into a file with specified file format" do
      path = File.tempname ".pdb"
      structure.write path, :xyz
      File.read(path).should eq <<-EOS
        3
        ICN
        I    -2.000    0.000    0.000
        C     0.000    0.000    0.000
        N     1.500    0.000    0.000

        EOS
      File.delete path
    end

    it "writes a structure into an IO" do
      io = IO::Memory.new
      structure.write io, :xyz
      io.to_s.should eq <<-EOS
        3
        ICN
        I    -2.000    0.000    0.000
        C     0.000    0.000    0.000
        N     1.500    0.000    0.000

        EOS
    end

    it "accepts file format as string" do
      io = IO::Memory.new
      structure.write io, "xyz"
      io.to_s.should eq <<-EOS
        3
        ICN
        I    -2.000    0.000    0.000
        C     0.000    0.000    0.000
        N     1.500    0.000    0.000

        EOS
    end

    it "raises on invalid file format" do
      expect_raises ArgumentError do
        structure.write IO::Memory.new, "asd"
      end
    end
  end

  describe "#cell" do
    it "raises if cell is nil" do
      expect_raises(Chem::Spatial::NotPeriodicError, "sulbactam is not periodic") do
        load_file("sulbactam.xyz").cell
      end
    end
  end

  describe "#extract" do
    it "returns a new structure with the selected atoms" do
      structure = Chem::Structure.read spec_file("1cbn.pdb")
      other = structure.extract &.name.==("CA")
      other.chains.map(&.spec).should eq structure.chains.map(&.spec)
      other.residues.map(&.spec).should eq structure.residues.select(&.protein?).map(&.spec)
      other.atoms.map(&.spec).should eq structure.atoms.select(&.name.==("CA")).map(&.spec)
      other.biases.should eq structure.biases
      other.cell.should eq structure.cell
      other.experiment.should eq structure.experiment
      other.source_file.should eq structure.source_file
      other.title.should eq structure.title
    end
  end

  describe "#delete" do
    it "deletes a chain" do
      structure = Chem::Structure.build do
        3.times { chain { } }
      end
      structure.chains.size.should eq 3
      structure.chains.map(&.id).should eq "ABC".chars

      structure.delete structure.chains[1]
      structure.chains.size.should eq 2
      structure.chains.map(&.id).should eq "AC".chars
      structure.dig?('B').should be_nil
    end

    it "does not delete another chain with the same id from the internal table (#86)" do
      structure = Chem::Structure.new
      Chem::Chain.new structure, 'A'
      Chem::Chain.new structure, 'B'
      Chem::Chain.new structure, 'A'

      structure.chains.size.should eq 3
      structure.chains.map(&.id).should eq "ABA".chars

      structure.delete structure.chains[0]

      structure.chains.size.should eq 2
      structure.chains.map(&.id).should eq "BA".chars
      structure.dig('A').should be structure.chains[1]
    end
  end

  describe "#dig" do
    structure = fake_structure

    it "returns a chain" do
      structure.dig('A').id.should eq 'A'
    end

    it "returns a residue" do
      structure.dig('A', 2).name.should eq "PHE"
      structure.dig('A', 2, nil).name.should eq "PHE"
    end

    it "returns an atom" do
      structure.dig('A', 2, "CA").name.should eq "CA"
      structure.dig('A', 2, nil, "CA").name.should eq "CA"
    end

    it "fails when index is invalid" do
      expect_raises(KeyError) { structure.dig 'C' }
      expect_raises(KeyError) { structure.dig 'A', 25 }
      expect_raises(KeyError) { structure.dig 'A', 2, "OH" }
    end
  end

  describe "#dig?" do
    structure = fake_structure

    it "returns nil when index is invalid" do
      structure.dig?('C').should be_nil
      structure.dig?('A', 25).should be_nil
      structure.dig?('A', 2, "OH").should be_nil
    end
  end

  describe "#guess_bonds" do
    it "guesses bonds from geometry" do
      structure = load_file("AlaIle--unwrapped.poscar")
      structure.guess_bonds

      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      structure.atoms.zip(n_bonds) do |atom, bonds|
        atom.bonds.size.should eq bonds
      end
      structure.atoms[0].bonded_atoms.map(&.number).sort!.should eq [2, 14, 15, 16]
      structure.atoms[4].bonded_atoms.map(&.number).sort!.should eq [4, 28, 30]
      structure.atoms[4].bonds[structure.atoms[27]].order.should eq 2
      structure.atoms[4].bonds[structure.atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      structure = load_file("k2p_pore_b.xyz")
      structure.guess_bonds
      structure.guess_formal_charges

      structure.bonds.size.should eq 644
      structure.bonds.sum(&.order.to_i).should eq 714
      structure.bonds.count(&.single?).should eq 574
      structure.bonds.count(&.double?).should eq 70

      structure.formal_charge.should eq 3
      structure.atoms.count(&.formal_charge.!=(0)).should eq 9

      # ions
      (638..641).each do |i|
        structure.atoms[i].valence.should eq 0
        structure.atoms[i].bonds.size.should eq 0
        structure.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      structure.atoms[324].valence.should eq 4
      structure.atoms[324].bonds.size.should eq 4
      structure.atoms[324].formal_charge.should eq 1

      # c-ter
      structure.atoms[364].valence.should eq 2
      structure.atoms[364].formal_charge.should eq 0
      structure.atoms[365].valence.should eq 1
      structure.atoms[365].formal_charge.should eq -1

      structure.atoms[149].bonded_atoms.map(&.number).should eq [145] # H near two Os

      # aromatic ring
      structure.atoms[427].bonds[structure.atoms[428]].order.should eq 1
      structure.atoms[428].bonds[structure.atoms[430]].order.should eq 2
      structure.atoms[430].bonds[structure.atoms[432]].order.should eq 1
      structure.atoms[432].bonds[structure.atoms[431]].order.should eq 2
      structure.atoms[431].bonds[structure.atoms[429]].order.should eq 1
      structure.atoms[429].bonds[structure.atoms[427]].order.should eq 2
    end

    it "guesses bonds from geometry having a sulfate ion" do
      structure = load_file("sulbactam.xyz")
      structure.guess_bonds
      structure.guess_formal_charges

      structure.bonds.size.should eq 27
      structure.bonds.sum(&.order.to_i).should eq 31
      structure.bonds.count(&.single?).should eq 23
      structure.bonds.count(&.double?).should eq 4

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[13].valence.should eq 2
      structure.atoms[13].bonded_atoms.map(&.number).sort!.should eq [13, 26]
      structure.atoms[14].valence.should eq 2
      structure.atoms[14].bonded_atoms.map(&.number).should eq [13]

      # sulfate ion
      structure.atoms[3].valence.should eq 6
      structure.atoms[3].bonded_atoms.map(&.number).sort!.should eq [2, 5, 6, 7]
      structure.atoms[3].bonds[structure.atoms[1]].single?.should be_true
      structure.atoms[3].bonds[structure.atoms[4]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[5]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[6]].single?.should be_true
    end

    it "guesses bonds from geometry of a protein having sulfur" do
      structure = load_file("acama.xyz")
      structure.guess_bonds
      structure.guess_formal_charges

      structure.bonds.size.should eq 60
      structure.bonds.sum(&.order.to_i).should eq 65
      structure.bonds.count(&.single?).should eq 55
      structure.bonds.count(&.double?).should eq 5

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[15].valence.should eq 2
      structure.atoms[15].bonded_atoms.map(&.number).should eq [15, 21]
      structure.atoms[15].bonds[structure.atoms[14]].single?.should be_true
      structure.atoms[15].bonds[structure.atoms[20]].single?.should be_true

      structure.atoms[37].valence.should eq 2
      structure.atoms[37].bonded_atoms.map(&.number).should eq [37, 39]
      structure.atoms[37].bonds[structure.atoms[36]].single?.should be_true
      structure.atoms[37].bonds[structure.atoms[38]].single?.should be_true
    end

    it "guesses bonds of unknown residues" do
      structure = load_file("residue_type_unknown_covalent_ligand.pdb")
      structure.guess_bonds

      structure.dig('A', 148, "C20").bonded?(structure.dig('A', 147, "SG")).should be_true
      structure.dig('A', 148, "C20").bonded?(structure.dig('A', 148, "N21")).should be_true
      structure.dig('A', 148, "S2").bonded?(structure.dig('A', 148, "O23")).should be_true
    end

    it "guesses bonds between terminal residues (periodic)" do
      structure = load_file("polyala--theta-240.000--c-24.70.pdb")
      structure.guess_bonds

      structure.residues.each do |residue|
        residue.pred?.should_not be_nil
        residue.succ?.should_not be_nil
      end
    end

    it "guesses bond order between atoms far apart in a periodic structure (#164)" do
      structure = load_file "polyala-beta--theta-180.000--c-10.00.poscar"
      structure.guess_bonds
      structure.guess_names
      structure.guess_formal_charges

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0
      structure.dig('A', 5, "C").bonds[structure.dig('A', 5, "O")].order.should eq 2
      structure.dig('B', 5, "C").bonds[structure.dig('B', 5, "O")].order.should eq 2
    end

    it "increases bond order of multi-valent atoms first" do
      structure = load_file("dmpe.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.bonds.select(&.double?)
        .map(&.atoms.map(&.name).to_a)
        .should eq [%w(P1 O1), %w(C5 O6), %w(C8 O8)]
      structure.atoms.reject(&.formal_charge.zero?)
        .to_h { |atom| {atom.name, atom.formal_charge} }
        .should eq({"N1" => 1, "O2" => -1})
    end

    it "guesses bonds of arginine" do
      structure = Chem::Structure.read spec_file("arginine.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.formal_charge.should eq 1
      structure.atoms.count(&.formal_charge.!=(0)).should eq 1
      structure.bonds.select(&.double?)
        .map(&.atoms.map(&.element.symbol).to_a.sort!.join('='))
        .tally.should eq({"C=N" => 1, "C=O" => 2})
    end

    it "guesses bonds of histidine" do
      structure = Chem::Structure.read spec_file("histidine.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0
      structure.bonds.select(&.double?)
        .map(&.atoms.map(&.element.symbol).to_a.sort!.join('='))
        .tally.should eq({"C=N" => 1, "C=O" => 2, "C=C" => 1})
    end

    it "works on a structure with bonds" do
      structure = Chem::Structure.read spec_file("5my.mol")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.formal_charge.should eq -10
      structure.atoms
        .reject(&.formal_charge.zero?)
        .count { |atom| atom.oxygen? && atom.bonded_atoms[-1].phosphorus? }
        .should eq 10
    end

    it "guesses aromatic 5-member N-heteroring" do
      expected = Chem::Structure.read spec_file("0f9.mol")
      structure = Chem::Structure.read spec_file("0f9.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.formal_charge.should eq expected.formal_charge
      structure.atoms.map(&.formal_charge).should eq expected.atoms.map(&.formal_charge)
      structure.bonds.tally_by(&.order).should eq expected.bonds.tally_by(&.order)
      structure.bonds.reject(&.single?).map(&.atoms.map(&.number)).sort!.should eq \
        expected.bonds.reject(&.single?).map(&.atoms.map(&.number)).sort!
    end

    it "guesses 0CB (#95)" do
      expected = Chem::Structure.read spec_file("0cb.mol2")
      structure = Chem::Structure.read spec_file("0cb.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.formal_charge.should eq expected.formal_charge
      structure.atoms.map(&.formal_charge).should eq expected.atoms.map(&.formal_charge)
      structure.bonds.size.should eq expected.bonds.size
      structure.bonds.tally_by(&.order).should eq expected.bonds.tally_by(&.order)
    end

    it "avoids strain rings in compressed FAD" do
      structure = Chem::Structure.read spec_file("FAD_strain.pdb")
      structure.guess_bonds
      structure.bonds.size.should eq 91
    end

    it "guesses conjugated aromatic 5-member N-heteroring" do
      structure = Chem::Structure.read spec_file("FAD_strain.pdb")
      structure.guess_bonds
      structure.bonds.tally_by(&.order.to_i).should eq({1 => 78, 2 => 13})
      structure.dig('A', 1, "N6").bonds[structure.dig('A', 1, "C23")].double?.should be_true
    end
  end

  describe "#guess_names" do
    it "guesses the topology of a dipeptide" do
      structure = load_file("AlaIle--unwrapped.poscar")
      structure.guess_bonds
      structure.guess_names

      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq %w(ALA ILE)
      structure.residues.map(&.number).should eq [1, 2]
      structure.residues.all?(&.protein?).should be_true
      structure.residues[0].atoms.map(&.name).should eq %w(
        N H1 H2 CA HA C O CB HB1 HB2 HB3)
      structure.residues[1].atoms.map(&.name).should eq %w(
        N H CA HA C O OXT HXT CB HB CG1 HG11 HG12 CD1 HD11 HD12 HD13 CG2 HG21 HG22 HG23)
    end

    it "guesses the topology of two peptide chains" do
      structure = load_file("5e61--unwrapped.poscar")
      structure.guess_bonds
      structure.guess_names

      structure.chains.map(&.id).should eq ['A', 'B']
      structure.chains.each do |chain|
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
      structure = load_file("5e61--off-center.poscar")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

      structure.chains.map(&.id).should eq ['A', 'B']
      structure.chains.each do |chain|
        chain.residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues.all?(&.protein?).should be_true
      end
    end

    it "guesses the topology of a broken peptide with waters" do
      structure = load_file("5e5v--unwrapped.poscar")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

      structure.chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      structure.chains[0].residues.map(&.name).sort!.should eq %w(ALA ASN GLY ILE LEU PHE SER)
      structure.chains[0].residues.map(&.number).should eq (1..7).to_a
      structure.chains[0].residues.all?(&.protein?).should be_true
      structure.chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER UNK)
      structure.chains[1].residues.map(&.number).should eq (1..7).to_a
      structure.chains[1].residues.all?(&.protein?).should be_true
      structure.chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      structure.chains[2].residues.map(&.number).should eq (1..7).to_a
      structure.chains[2].residues.all?(&.solvent?).should be_true
      structure.chains[3].residues.map(&.name).should eq %w(UNK)
      structure.chains[3].residues.map(&.number).should eq [1]
      structure.chains[3].residues.all?(&.other?).should be_true
    end

    it "guesses the topology of a periodic peptide" do
      structure = load_file("hlx_gly.poscar")
      structure.guess_bonds
      structure.guess_names

      structure.chains.map(&.id).should eq ['A']
      structure.chains[0].residues.map(&.name).should eq ["GLY"] * 13
      structure.chains[0].residues.map(&.number).should eq (1..13).to_a
      structure.chains[0].residues.all?(&.protein?).should be_true
    end

    it "guesses the topology of many fragments (beyond max chain id)" do
      structure = load_file("many_fragments.poscar")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

      structure.chains.size.should eq 1
      structure.residues.size.should eq 144
      structure.atoms.fragments.size.should eq 72
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq ["PHE"] * 144
      structure.residues.map(&.number).should eq (1..144).to_a
      structure.residues.all?(&.protein?).should be_true
    end

    it "detects multiple residues for unmatched atoms (#16)" do
      structure = load_file("peptide_unknown_residues.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

      structure.residues.size.should eq 9
      structure.residues.map(&.name).should eq %w(ALA LEU UNK VAL THR LEU SER UNK ALA)
      structure.residues[2].atoms.size.should eq 14
      structure.residues[7].atoms.size.should eq 8
      structure.residues.all?(&.protein?).should be_true
    end

    it "renames unmatched atoms" do
      structure = load_file("peptide_unknown_residues.xyz")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

      structure.dig('A', 3).name.should eq "UNK"
      structure.dig('A', 3).atoms.map(&.name).should eq %w(N1 C1 C2 O1 C3 O2 H1 H2 H3 H4 C4 H5 H6 H7)
      structure.dig('A', 8).name.should eq "UNK"
      structure.dig('A', 8).atoms.map(&.name).should eq %w(N1 C1 C2 O1 S1 H1 H2 H3)
    end

    it "guesses the topology of non-standard atoms (#21)" do
      structure = load_file("5e5v.pdb")
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names

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

    it "guesses the topology of an entire protein" do
      structure = load_file "1h1s_a--prepared.pdb"
      expected = structure.residues.join(&.code)

      structure = Chem::Structure.from_xyz IO::Memory.new(structure.to_xyz)
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names
      structure.residues.join(&.code).should eq expected
    end

    it "guesses the topology of a phospholipid" do
      Chem::Templates.load spec_file("dmpe.mol2")
      structure = load_file "dmpe.xyz"
      structure.guess_bonds
      structure.guess_formal_charges
      structure.guess_names
      structure.residues.size.should eq 1
      structure.residues[0].name.should eq "DMP"
    end

    it "sorts atoms with ter" do
      registry = Chem::Templates::Registry.new
      registry.parse <<-YAML
        templates:
          - description: cis-1,4-isoprene
            name: IPZ
            spec: C1-C2=C3(-C4)-C5
            link_bond: "C5-C1"
        ters:
          - description: 1-4-isoprene begin
            name: IPL
            spec: C1{-C}
            root: C1
          - description: 1-4-isoprene end
            name: IPR
            spec: C5{-C}
            root: C5
        YAML

      struc = Chem::Structure.read spec_file("isoprene-5.xyz")
      struc.guess_bonds
      struc.guess_formal_charges
      struc.guess_names registry

      struc.residues.map(&.name).should eq %w(IPZ) * 5
      struc.bonds.count(&.double?).should eq 5
      struc.bonds.select(&.double?).map(&.atoms.map(&.name)).uniq.should eq [{"C2", "C3"}]
      struc.residues[0].atoms.map(&.name).should eq %w(
        C1 H11 H12 H13 C2 H2 C3 C4 H41 H42 H43 C5 H51 H52)
      struc.residues[1...-1].each do |res|
        res.atoms.map(&.name).should eq %w(C1 H11 H12 C2 H2 C3 C4 H41 H42 H43 C5 H51 H52)
      end
      struc.residues[-1].atoms.map(&.name).should eq %w(
        C1 H11 H12 C2 H2 C3 C4 H41 H42 H43 C5 H51 H52 H53)
    end
  end

  describe "#guess_unknown_residue_types" do
    it "guesses type of unknown residue when previous is known" do
      structure = load_file("residue_type_unknown_previous.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues[1].protein?.should be_true
    end

    it "guesses type of unknown residue when next is known" do
      structure = load_file("residue_type_unknown_next.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues[0].protein?.should be_true
    end

    it "guesses type of unknown residue when its flanked by known residues" do
      structure = load_file("residue_type_unknown_flanked.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues[1].protein?.should be_true
    end

    it "does not guess type of unknown residue" do
      structure = load_file("residue_type_unknown_single.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues[0].other?.should be_true
    end

    it "does not guess type of unknown residue when its not connected to others" do
      structure = load_file("residue_type_unknown_next_gap.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues.first.other?.should be_true
    end

    it "does not guess type of unknown residue when it's not bonded by link bond" do
      structure = load_file("residue_type_unknown_covalent_ligand.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues.map(&.type.to_s).should eq %w(Protein Protein Protein Other)
    end

    it "guess type of unknown residue with non-standard atom names" do
      structure = load_file("residue_unknown_non_standard_names.pdb")
      structure.guess_bonds
      structure.guess_unknown_residue_types
      structure.residues.all?(&.protein?).should be_true
    end
  end

  describe "#apply_templates" do
    it "assigns bonds, formal charges, and residue templates" do
      structure = fake_structure(include_bonds: false)
      structure.apply_templates

      r1, r2, r3 = structure.residues

      [r1, r2, r3].all?(&.protein?).should be_true
      [r1, r2, r3].map(&.atoms.sum(&.formal_charge)).should eq [-1, 0, 0]

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
      structure.apply_templates

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1, 0, 0, 0, 0]
    end

    it "works for cyanide" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::C, vec3(0, 0, 0)
        atom Chem::PeriodicTable::N, vec3(1.16, 0, 0)
        bond 1, 2, :triple
      end
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

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
      structure.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1, 0, 0, 0, 0, 0, 0]
    end

    it "works for monoatomic cations (K+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::K, vec3(0, 0, 0)
      end
      structure.guess_formal_charges

      structure.formal_charge.should eq 1
      structure.atoms.map(&.formal_charge).should eq [1]
    end

    it "works for monoatomic cations (Mg2+)" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Mg, vec3(0, 0, 0)
      end
      structure.guess_formal_charges

      structure.formal_charge.should eq 2
      structure.atoms.map(&.formal_charge).should eq [2]
    end

    it "works for monoatomic anions" do
      structure = Chem::Structure.build do
        atom Chem::PeriodicTable::Cl, vec3(0, 0, 0)
      end
      structure.guess_formal_charges

      structure.formal_charge.should eq -1
      structure.atoms.map(&.formal_charge).should eq [-1]
    end
  end

  describe "#renumber_residues_by" do
    it "renumbers residues by the given order" do
      structure = load_file("3sgr.pdb")
      expected = structure.chains.map { |chain| chain.residues.sort_by(&.code) }
      structure.renumber_residues_by(&.code)
      structure.chains.map(&.residues).should eq expected
    end
  end

  describe "#renumber_residues_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file("5e5v--unwrapped.poscar", guess_bonds: true, guess_names: true)
      structure.renumber_residues_by_connectivity split_chains: false

      chains = structure.chains
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
      structure = load_file("hlx_gly.poscar")
      structure.residues.each_cons_pair do |a, b|
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
        structure = load_file(filename, guess_bonds: true, guess_names: true)
        structure.renumber_residues_by_connectivity
        residues = structure.residues.to_a.sort_by(&.number)
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
      structure = load_file("cylindrin--size-09.pdb")
      structure.renumber_residues_by_connectivity split_chains: false
      structure.chains.map(&.id).should eq "ABC".chars
      structure.chains.map(&.residues.size).should eq [18] * 3
      structure.chains.map(&.residues.map(&.number)).should eq [(1..18).to_a] * 3
      structure.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 3
    end

    it "splits chains (#85)" do
      structure = load_file("cylindrin--size-09.pdb")
      structure.renumber_residues_by_connectivity split_chains: true
      structure.chains.map(&.id).should eq "ABCDEF".chars
      structure.chains.map(&.residues.size).should eq [9] * 6
      structure.chains.map(&.residues.map(&.number)).should eq [(1..9).to_a] * 6
      structure.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 6
    end
  end

  describe "#bonds" do
    it "returns the bonds" do
      structure = load_file("benzene.mol2")
      structure.bonds.map(&.atoms.map(&.number)).sort!.should eq [
        {1, 2}, {1, 6}, {1, 7}, {2, 3}, {2, 8}, {3, 4}, {3, 9}, {4, 5},
        {4, 10}, {5, 6}, {5, 11}, {6, 12},
      ]
    end
  end

  describe "#guess_angles" do
    it "computes the angles" do
      structure = load_file("8FX.mol2")
      structure.guess_angles
      structure.angles.map(&.atoms.map(&.number)).sort!.should eq [
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
      structure = load_file("8FX.mol2")
      structure.guess_dihedrals
      structure.dihedrals.map(&.atoms.map(&.number)).sort!.should eq [
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
      structure = load_file("8FX.mol2")
      structure.guess_impropers
      structure.impropers.map(&.atoms.map(&.number)).sort!.should eq [
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
        Chem::Structure.guess_element("X1")
      end
    end
  end

  describe ".guess_element?" do
    it "returns the element by atom name" do
      # TODO: test different atom names (#116)
      Chem::Structure.guess_element?("O").should be Chem::PeriodicTable::O
      Chem::Structure.guess_element?("CA").should be Chem::PeriodicTable::C
    end

    it "returns nil if unknown" do
      Chem::Structure.guess_element?("X1").should be_nil
    end
  end

  describe "#reset_connectivity" do
    it "deletes bonds and formal charges" do
      structure = Chem::Structure.read spec_file("5my.mol")
      structure.bonds.should_not be_empty
      structure.formal_charge.should eq -10
      structure.reset_connectivity
      structure.bonds.should be_empty
      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0
    end
  end

  describe "#coords" do
    it "sets the coordinates from an enumerable" do
      struc = Chem::Structure.from_xyz spec_file("waters.xyz")
      expected = struc.coords.map(&.*(2))
      struc.coords = expected
      struc.coords.to_a.should eq expected
    end

    it "sets the coordinates from coords" do
      struc = Chem::Structure.from_xyz spec_file("waters.xyz")
      expected = struc.coords.map(&.*(0.5))
      struc.coords = struc.clone.coords.map!(&.*(0.5))
      struc.coords.to_a.should eq expected
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

describe Chem::ChainView do
  chains = fake_structure.chains

  describe "#[]" do
    it "gets chain by zero-based index" do
      chains[0].id.should eq 'A'
    end
  end

  describe "#residues" do
    it "returns the residues" do
      fake_structure.chains.residues.size.should eq 3
      fake_structure.chains.residues.map(&.name).should eq %w(ASP PHE SER)
    end
  end
end
