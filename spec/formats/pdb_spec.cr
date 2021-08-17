require "../spec_helper"

describe Chem::PDB do
  # TODO test partial occupancy and insertion code (5tun)
  describe ".parse" do
    it "parses a (real) PDB file" do
      st = load_file "1h1s.pdb"
      st.n_atoms.should eq 9701
      st.formal_charge.should eq -44

      st.chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      st.chains['A'].n_residues.should eq 569
      st.chains['B'].n_residues.should eq 440
      st.chains['C'].n_residues.should eq 436
      st.chains['D'].n_residues.should eq 370

      st['A'][290].kind.protein?.should be_true
      st['A'][1298].kind.other?.should be_true
      st['A'][2008].kind.solvent?.should be_true
      st['D'][342].kind.protein?.should be_true
      st['D'][2080].kind.solvent?.should be_true

      atom = st.atoms[-1]
      atom.serial.should eq 9705
      atom.name.should eq "O"
      atom.residue.name.should eq "HOH"
      atom.chain.id.should eq 'D'
      atom.residue.number.should eq 2112
      atom.coords.should eq Vector[66.315, 27.887, 48.252]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 53.58
      atom.element.oxygen?.should be_true
      atom.formal_charge.should eq 0
    end

    it "parses a PDB file" do
      st = load_file "simple.pdb"
      st.experiment.should be_nil
      st.title.should eq "Glutamate"
      st.n_atoms.should eq 13
      st.n_chains.should eq 1
      st.n_residues.should eq 3
      st.atoms.map(&.element.symbol).should eq ["C", "O", "O", "N", "C", "C", "O",
                                                "C", "C", "C", "O", "O", "N"]
      st.atoms.map(&.formal_charge).should eq [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1]

      atom = st.atoms[11]
      atom.serial.should eq 12
      atom.name.should eq "OE2"
      atom.residue.name.should eq "GLU"
      atom.chain.id.should eq 'A'
      atom.residue.number.should eq 2
      # atom.insertion_code.should be_nil
      atom.coords.should eq Vector[-1.204, 4.061, 0.195]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 0
      atom.element.oxygen?.should be_true
      atom.formal_charge.should eq -1
    end

    it "parses a PDB file without elements" do
      st = load_file "no_elements.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without elements and irregular line width (77)" do
      st = load_file "no_elements_irregular_end.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges" do
      st = load_file "no_charges.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges and irregular line width (79)" do
      st = load_file "no_charges_irregular_end.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without trailing spaces" do
      st = load_file "no_trailing_spaces.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file with long title" do
      st = load_file "title_long.pdb"
      st.title.should eq "STRUCTURE OF THE TRANSFORMED MONOCLINIC LYSOZYME BY " \
                         "CONTROLLED DEHYDRATION"
    end

    it "parses a PDB file with numbers in hexadecimal representation" do
      st = load_file "big_numbers.pdb"
      st.n_atoms.should eq 6
      st.atoms.map(&.serial).should eq (99995..100000).to_a
      st.residues.map(&.number).should eq [9999, 10000]
    end

    it "parses a PDB file with unit cell parameters" do
      st = load_file "1crn.pdb"
      st.lattice.should_not be_nil
      lattice = st.lattice.not_nil!
      lattice.size.should eq S[40.960, 18.650, 22.520]
      lattice.alpha.should eq 90
      lattice.beta.should eq 90.77
      lattice.gamma.should eq 90
    end

    it "parses a PDB file with experimental header" do
      st = load_file "1crn.pdb"
      st.title.should eq "1CRN"
      st.experiment.should_not be_nil
      exp = st.experiment.not_nil!
      exp.deposition_date.should eq Time.utc(1981, 4, 30)
      exp.doi.should eq "10.1073/PNAS.81.19.6014"
      exp.method.x_ray_diffraction?.should be_true
      exp.pdb_accession.should eq "1CRN"
      exp.resolution.should eq 1.5
      exp.title.should eq "WATER STRUCTURE OF A HYDROPHOBIC PROTEIN AT ATOMIC " \
                          "RESOLUTION. PENTAGON RINGS OF WATER MOLECULES IN CRYSTALS " \
                          "OF CRAMBIN"
    end

    it "parses experiment with multiple methods" do
      structure = Chem::Structure.from_pdb IO::Memory.new <<-EOS
        HEADER    CHAPERONE                               14-FEB-13   4J7Z
        TITLE     THERMUS THERMOPHILUS DNAJ J- AND G/F-DOMAINS
        EXPDTA    X-RAY DIFFRACTION; EPR
        ATOM      1  N   ALA A   1       5.606   4.546  11.941  1.00  3.73           N
        ATOM      2  CA  ALA A   1       5.598   5.767  11.082  1.00  3.56           C
        ATOM      3  C   ALA A   1       6.441   5.527   9.850  1.00  4.13           C
        ATOM      4  O   ALA A   1       6.052   5.933   8.744  1.00  4.36           O
        ATOM      5  CB  ALA A   1       6.022   6.977  11.891  1.00  4.80           C
        EOS
      structure.experiment.should_not be_nil
      expt = structure.experiment.not_nil!
      expt.method.x_ray_diffraction?.should be_true
    end

    it "parses a PDB file with sequence" do
      st = load_file "1crn.pdb"
      st.sequence.should_not be_nil
      seq = st.sequence.not_nil!
      seq.to_s.should eq "TTCCPSIVARSNFNVCRLPGTPEAICATYTGCIIIPGATCPGDYAN"
    end

    it "parses a PDB file with anisou/ter records" do
      st = load_file "anisou.pdb"
      st.n_atoms.should eq 133
      st.residues.map(&.number).should eq (32..52).to_a
    end

    it "parses a PDB file with deuterium" do
      st = load_file "isotopes.pdb"
      st.n_atoms.should eq 12
      st.atoms[5].element.symbol.should eq "D"
    end

    it "parses a PDB file with element X (ASX case)" do
      st = load_file "3e2o.pdb"
      st.residues[serial: 235]["XD1"].element.should be PeriodicTable::X
    end

    it "parses a PDB file with SIG* records" do
      st = load_file "1etl.pdb"
      st.n_atoms.should eq 160
      st.residues[serial: 6]["SG"].bonded?(st.residues[serial: 14]["SG"]).should be_true
    end

    it "parses secondary structure information" do
      st = load_file "1crn.pdb"
      st.residues[0].dssp.should eq 'E'
      st.residues[1].dssp.should eq 'E'
      st.residues[3].dssp.should eq 'E'
      st.residues[4].dssp.should eq '0'
      st.residues[5].dssp.should eq '0'
      st.residues[6].dssp.should eq 'H'
      st.residues[18].dssp.should eq 'H'
      st.residues[19].dssp.should eq '0'
      st.residues[31].dssp.should eq 'E'
      st.residues[-1].dssp.should eq '0'
    end

    it "parses secondary structure information with insertion codes" do
      st = load_file "secondary_structure_inscode.pdb"
      st.residues.map(&.dssp).should eq "HHHHHH000000EEEHH000".chars
    end

    it "parses secondary structure information when sheet type is missing" do
      st = load_file "secondary_structure_missing_type.pdb"
      st.residues.map(&.sec.code).should eq "0EE00EEEEE0".chars
    end

    it "parses bonds" do
      st = load_file "1crn.pdb"
      st.atoms[19].bonds[st.atoms[281]].order.should eq 1
      st.atoms[25].bonds[st.atoms[228]].order.should eq 1
      st.atoms[115].bonds[st.atoms[187]].order.should eq 1
    end

    it "parses bonds when multiple models" do
      models = Array(Chem::Structure).from_pdb "spec/data/pdb/models.pdb"
      models.size.should eq 4
      models.each do |st|
        st.atoms[0].bonds[st.atoms[1]].order.should eq 1
        st.atoms[1].bonds[st.atoms[2]].order.should eq 1
        st.atoms[1].bonds[st.atoms[4]].order.should eq 1
        st.atoms[2].bonds[st.atoms[3]].order.should eq 1
      end
    end

    it "parses duplicate bonds" do
      st = load_file "duplicate_bonds.pdb"
      st.atoms[0].bonds[st.atoms[1]].order.should eq 1
      st.atoms[1].bonds[st.atoms[2]].order.should eq 2
      st.atoms[2].bonds[st.atoms[3]].order.should eq 1
      st.atoms[3].bonds[st.atoms[4]].order.should eq 2
      st.atoms[4].bonds[st.atoms[5]].order.should eq 1
      st.atoms[5].bonds[st.atoms[0]].order.should eq 2
    end

    it "parses alternate conformations" do
      structure = load_file "alternate_conf.pdb"
      structure.n_residues.should eq 1
      structure.n_atoms.should eq 8
      structure.each_atom.map(&.occupancy).uniq.to_a.should eq [1, 0.37]
      structure['A'][1]["N"].x.should eq 7.831
      structure['A'][1]["OD1"].x.should eq 10.427
    end

    it "parses alternate conformations with different residues" do
      structure = load_file "alternate_conf_mut.pdb"
      structure.n_residues.should eq 1
      structure.n_atoms.should eq 14
      structure.each_atom.map(&.occupancy).uniq.to_a.should eq [0.56]
      structure['A'][1].name.should eq "TRP"
      structure['A'][1]["N"].coords.should eq V[3.298, 2.388, 22.684]
    end

    it "parses selected alternate conformation" do
      structure = Chem::Structure.from_pdb "spec/data/pdb/alternate_conf_mut.pdb", alt_loc: 'B'
      structure.n_residues.should eq 1
      structure.n_atoms.should eq 11
      structure.each_atom.map(&.occupancy).uniq.to_a.should eq [0.22]
      structure['A'][1].name.should eq "ARG"
      structure['A'][1]["CB"].coords.should eq V[4.437, 2.680, 20.555]
    end

    it "parses insertion codes" do
      residues = load_file("insertion_codes.pdb").residues
      residues.size.should eq 7
      residues.map(&.number).should eq [75, 75, 75, 75, 75, 75, 76]
      residues.map(&.insertion_code).should eq [nil, 'A', 'B', 'C', 'D', 'E', nil]
    end

    it "parses multiple models" do
      st_list = Array(Chem::Structure).from_pdb "spec/data/pdb/models.pdb"
      st_list.size.should eq 4
      xs = {5.606, 7.212, 5.408, 22.055}
      st_list.zip(xs) do |st, x|
        st.n_atoms.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "parses selected models" do
      path = "spec/data/pdb/models.pdb"
      st_list = Array(Chem::Structure).from_pdb path, indexes: [1, 3]
      st_list.size.should eq 2
      xs = {7.212, 22.055}
      st_list.zip(xs) do |st, x|
        st.n_atoms.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "skip models" do
      PDB::Reader.open("spec/data/pdb/models.pdb") do |reader|
        reader.skip_entry
        reader.read_entry.atoms[0].coords.should eq V[7.212, 15.334, 0.966]
        reader.skip_entry
        reader.read_entry.atoms[0].coords.should eq V[22.055, 14.701, 7.032]
      end
    end

    it "parses selected chains" do
      structure = Chem::Structure.from_pdb "spec/data/pdb/5jqf.pdb", chains: ['B']
      structure.n_chains.should eq 1
      structure.n_residues.should eq 38
      structure.n_atoms.should eq 310
      structure.chains.map(&.id).should eq ['B']
      structure.sequence.to_s.should eq "GIEPLGPVDEDQGEHYLFAGG"
      structure['B'][18].sec.code.should eq 'E'
    end

    it "parses only protein" do
      structure = Chem::Structure.from_pdb "spec/data/pdb/5jqf.pdb", het: false
      structure.n_chains.should eq 2
      structure.n_residues.should eq 42
      structure.n_atoms.should eq 586
    end

    it "parses file without the END record" do
      st = load_file "no_end.pdb"
      st.n_atoms.should eq 6
      st.chains.map(&.id).should eq ['A']
      st.residues.map(&.number).should eq [0]
      st.residues.map(&.name).should eq ["SER"]
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG"]
    end

    it "parses 1cbn (alternate conformations)" do
      structure = load_file "1cbn.pdb"
      structure.n_atoms.should eq 644
      structure.n_chains.should eq 1
      structure.n_residues.should eq 47
      structure.residues.map(&.number).should eq ((1..46).to_a << 66)

      residue = structure['A'][22]
      residue.name.should eq "PRO"
      residue.n_atoms.should eq 14
      residue.each_atom.map(&.occupancy).uniq.to_a.should eq [0.6]

      residue = structure['A'][23]
      residue.n_atoms.should eq 15
      residue.each_atom.map(&.occupancy).uniq.to_a.should eq [1, 0.8]
      residue["CG"].coords.should eq V[10.387, 12.021, 0.058]
    end

    it "parses 1dpo (insertions)" do
      st = load_file "1dpo.pdb"
      st.n_atoms.should eq 1921
      st.n_chains.should eq 1
      st.n_residues.should eq 446

      missing = {35, 36, 68, 126, 131, 205, 206, 207, 208, 218}
      resids = [] of Tuple(Int32, Char?)
      resids.concat (16..246).reject { |i| missing.includes? i }.map { |i| {i, nil} }
      resids.concat [250, 251, 247, 248, 249].map { |num| {num, nil} }
      resids.concat (252..468).map { |num| {num, nil} }
      {184, 188, 221}.each do |i|
        resids.insert resids.index!({i, nil}) + 1, {i, 'A'}
      end
      st.residues.map { |res| {res.number, res.insertion_code} }.should eq resids
    end

    it "does not assign bonds for skipped atoms" do
      # it triggered IndexError for skipped atoms, but cannot test
      # whether bonds are assigned from PDB or not since missing bonds
      # are automatically guessed
      Structure.from_pdb "spec/data/pdb/1crn.pdb", chains: ['C']
    end

    it "parses first chain" do
      structure = Structure.from_pdb "spec/data/pdb/multiple_chains.pdb", chains: "first"
      structure.n_chains.should eq 1
      structure.n_residues.should eq 2
      structure.n_atoms.should eq 14
      structure.chains[0].id.should eq 'J'
    end

    it "parses left-justified element (#84)" do
      io = IO::Memory.new <<-EOS
        ATOM      1  N   GLY     1     -20.286 -37.665  -6.811  1.00  0.00          N
        ATOM      2  H1  GLY     1     -20.247 -38.062  -5.872  1.00  0.00          H
        ATOM      3  H2  GLY     1     -20.074 -36.616  -6.704  1.00  0.00          H
        ATOM      4  H3  GLY     1     -21.301 -37.774  -7.185  1.00  0.00          H
        ATOM      5  CA  GLY     1     -19.299 -38.321  -7.682  1.00  0.00          C
        EOS
      s = Chem::Structure.from_pdb io
      s.atoms.map(&.element.symbol).should eq %w(N H H H C)
    end

    it "parses a PDB header" do
      expt = Chem::Structure::Experiment.from_pdb "spec/data/pdb/1crn.pdb"
      expt.deposition_date.should eq Time.utc(1981, 4, 30)
      expt.doi.should eq "10.1073/PNAS.81.19.6014"
      expt.method.x_ray_diffraction?.should be_true
      expt.pdb_accession.should eq "1CRN"
      expt.resolution.should eq 1.5
      expt.title.should eq "WATER STRUCTURE OF A HYDROPHOBIC PROTEIN AT ATOMIC \
                            RESOLUTION. PENTAGON RINGS OF WATER MOLECULES IN CRYSTALS \
                            OF CRAMBIN"
    end
  end
end

describe Chem::PDB::Writer do
  it "writes a structure" do
    structure = load_file "1crn.pdb", topology: :templates
    expected = File.read "spec/data/pdb/1crn--stripped.pdb"
    structure.to_pdb.should eq expected
  end

  it "writes an atom collection" do
    structure = load_file "1crn.pdb", topology: :none
    structure.residues[4].to_pdb.should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      ATOM      1  N   PRO A   5       9.561   9.108  13.563  1.00  3.96           N  
      ATOM      2  CA  PRO A   5       9.448   9.034  15.012  1.00  4.25           C  
      ATOM      3  C   PRO A   5       9.288   7.670  15.606  1.00  4.96           C  
      ATOM      4  O   PRO A   5       9.490   7.519  16.819  1.00  7.44           O  
      ATOM      5  CB  PRO A   5       8.230   9.957  15.345  1.00  5.11           C  
      ATOM      6  CG  PRO A   5       7.338   9.786  14.114  1.00  5.24           C  
      ATOM      7  CD  PRO A   5       8.366   9.804  12.958  1.00  5.20           C  
      END                                                                             \n
      EOS
  end

  it "writes ter records at the end of polymer chains" do
    content = File.read "spec/data/pdb/5e5v.pdb"
    structure = Chem::Structure.from_pdb IO::Memory.new(content), guess_topology: false
    structure.to_pdb.should eq content
  end

  it "keeps original atom numbering" do
    structure = load_file "1crn.pdb"
    structure.residues[4].to_pdb(renumber: false).should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      ATOM     27  N   PRO A   5       9.561   9.108  13.563  1.00  3.96           N  
      ATOM     28  CA  PRO A   5       9.448   9.034  15.012  1.00  4.25           C  
      ATOM     29  C   PRO A   5       9.288   7.670  15.606  1.00  4.96           C  
      ATOM     30  O   PRO A   5       9.490   7.519  16.819  1.00  7.44           O  
      ATOM     31  CB  PRO A   5       8.230   9.957  15.345  1.00  5.11           C  
      ATOM     32  CG  PRO A   5       7.338   9.786  14.114  1.00  5.24           C  
      ATOM     33  CD  PRO A   5       8.366   9.804  12.958  1.00  5.20           C  
      END                                                                             \n
      EOS
  end

  it "writes CONECT records" do
    structure = Chem::Structure.build(guess_topology: false) do
      residue "ICN" do
        atom :i, V[-1, 0, 0]
        atom :c, V[0, 0, 0]
        atom :n, V[1, 0, 0]

        bond "I1", "C1"
        bond "C1", "N1", order: 3
      end
    end

    structure.to_pdb(bonds: true).should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      HETATM    1  I1  ICN A   1      -1.000   0.000   0.000  1.00  0.00           I  
      HETATM    2  C1  ICN A   1       0.000   0.000   0.000  1.00  0.00           C  
      HETATM    3  N1  ICN A   1       1.000   0.000   0.000  1.00  0.00           N  
      CONECT    1    2
      CONECT    2    1    3    3    3
      CONECT    3    2    2    2
      END                                                                             \n
      EOS
  end

  it "writes CONECT records for renumbered atoms" do
    structure = Chem::Structure.build(guess_topology: false) do
      residue "ICN" do
        atom :i, V[-1, 0, 0]
        atom :c, V[0, 0, 0]
        atom :n, V[1, 0, 0]

        bond "I1", "C1"
        bond "C1", "N1", order: 3
      end

      residue "ICN" do
        atom :i, V[-4, 0, 0]
        atom :c, V[-3, 0, 0]
        atom :n, V[-2, 0, 0]

        bond "I1", "C1"
        bond "C1", "N1", order: 3
      end
    end

    structure.residues[1].to_pdb(bonds: true).should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      HETATM    1  I1  ICN A   2      -4.000   0.000   0.000  1.00  0.00           I  
      HETATM    2  C1  ICN A   2      -3.000   0.000   0.000  1.00  0.00           C  
      HETATM    3  N1  ICN A   2      -2.000   0.000   0.000  1.00  0.00           N  
      CONECT    1    2
      CONECT    2    1    3    3    3
      CONECT    3    2    2    2
      END                                                                             \n
      EOS
  end

  it "writes CONECT records for specified bonds" do
    structure = Chem::Structure.build(guess_topology: false) do
      residue "CH3" do
        atom :c, V[0, 0, 0]
        atom :h, V[0, -1, 0]
        atom :h, V[1, 0, 0]
        atom :h, V[0, 1, 0]

        bond "C1", "H1"
        bond "C1", "H2"
        bond "C1", "H3"
      end
    end

    bonds = [structure.atoms[0].bonds[structure.atoms[2]]]
    structure.to_pdb(bonds: bonds).should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      HETATM    1  C1  CH3 A   1       0.000   0.000   0.000  1.00  0.00           C  
      HETATM    2  H1  CH3 A   1       0.000  -1.000   0.000  1.00  0.00           H  
      HETATM    3  H2  CH3 A   1       1.000   0.000   0.000  1.00  0.00           H  
      HETATM    4  H3  CH3 A   1       0.000   1.000   0.000  1.00  0.00           H  
      CONECT    1    3
      CONECT    3    1
      END                                                                             \n
      EOS
  end

  it "writes big numbers" do
    structure = Chem::Structure.build(guess_topology: false) do
      residue "ICN" do
        atom :i, V[-1, 0, 0]
        atom :c, V[0, 0, 0]
        atom :n, V[1, 0, 0]

        bond "I1", "C1"
        bond "C1", "N1", order: 3
      end
    end
    structure.atoms[0].serial = 99_999
    structure.atoms[1].serial = 100_000
    structure.atoms[2].serial = 235_123
    structure.residues[0].number = 10_231

    structure.to_pdb(bonds: true, renumber: false).should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      HETATM99999  I1  ICN AA06F      -1.000   0.000   0.000  1.00  0.00           I  
      HETATMA0000  C1  ICN AA06F       0.000   0.000   0.000  1.00  0.00           C  
      HETATMA2W9F  N1  ICN AA06F       1.000   0.000   0.000  1.00  0.00           N  
      CONECT99999A0000
      CONECTA000099999A2W9FA2W9FA2W9F
      CONECTA2W9FA0000A0000A0000
      END                                                                             \n
      EOS
  end

  it "writes four-letter residue names (#45)" do
    structure = Chem::Structure.build(guess_topology: false) do
      residue "DMPG" do
        atom "C13", V[9.194, 10.488, 13.865]
        atom "H13A", V[8.843, 9.508, 14.253]
        atom "H13B", V[10.299, 10.527, 13.756]
        atom "OC3", V[8.600, 10.828, 12.580]
      end
    end
    structure.to_pdb.should eq <<-EOS
      REMARK   4                                                                      
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         
      HETATM    1  C13 DMPGA   1       9.194  10.488  13.865  1.00  0.00           C  
      HETATM    2 H13A DMPGA   1       8.843   9.508  14.253  1.00  0.00           H  
      HETATM    3 H13B DMPGA   1      10.299  10.527  13.756  1.00  0.00           H  
      HETATM    4  OC3 DMPGA   1       8.600  10.828  12.580  1.00  0.00           O  
      END                                                                             \n
      EOS
  end

  it "writes multiple entries" do
    path = "spec/data/pdb/models.pdb"
    entries = Array(Structure).from_pdb path
    entries.to_pdb.should eq File.read(path).gsub(/CONECT.+\n/, "")
  end

  it "writes an indeterminate number of entries" do
    path = "spec/data/pdb/models.pdb"
    entries = Array(Structure).from_pdb path

    io = IO::Memory.new
    Chem::PDB::Writer.open(io) do |writer|
      entries.each do |entry|
        writer << entry
      end
    end
    io.to_s.should eq File.read(path).gsub(/(NUMMDL|CONECT).+\n/, "")
  end
end
