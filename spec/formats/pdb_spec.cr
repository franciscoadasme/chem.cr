require "../spec_helper"

describe Chem::PDB do
  describe ".parse" do
    it "parses a (real) PDB file" do
      st = load_file "1h1s.pdb"
      st.source_file.should eq Path[spec_file("1h1s.pdb")].expand
      st.atoms.size.should eq 9701

      # Charges are set from templates only due to missing hydrogens
      st.formal_charge.should eq 0
      st.chains.map(&.atoms.sum(&.formal_charge)).should eq [3, -3, 3, -3]
      # TPO160(-2) is unknown so formal charges aren't assigned
      st.dig('A', 160).atoms.sum(&.formal_charge).should eq 0
      st.dig('C', 160).atoms.sum(&.formal_charge).should eq 0
      # N-ter (175) is not matched by templates so N is left uncharged
      st.dig('B', 175).atoms.sum(&.formal_charge).should eq 0
      st.dig('D', 175).atoms.sum(&.formal_charge).should eq 0

      st.chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      st.chains['A'].residues.size.should eq 569
      st.chains['B'].residues.size.should eq 440
      st.chains['C'].residues.size.should eq 436
      st.chains['D'].residues.size.should eq 370

      st['A'][290].type.protein?.should be_true
      st['A'][1298].type.other?.should be_true
      st['A'][2008].type.solvent?.should be_true
      st['D'][342].type.protein?.should be_true
      st['D'][2080].type.solvent?.should be_true

      atom = st.atoms[-1]
      atom.serial.should eq 9705
      atom.name.should eq "O"
      atom.residue.name.should eq "HOH"
      atom.chain.id.should eq 'D'
      atom.residue.number.should eq 2112
      atom.coords.should eq [66.315, 27.887, 48.252]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 53.58
      atom.element.oxygen?.should be_true
      atom.formal_charge.should eq 0
    end

    it "parses a PDB file" do
      st = load_file "simple.pdb"
      st.source_file.should eq Path[spec_file("simple.pdb")].expand
      st.experiment.should be_nil
      st.title.should eq "Glutamate"
      st.atoms.size.should eq 13
      st.chains.size.should eq 1
      st.residues.size.should eq 3
      st.atoms.map(&.element.symbol).should eq ["C", "O", "O", "N", "C", "C", "O",
                                                "C", "C", "C", "O", "O", "N"]
      # Formal charges are only assigned from templates if hydrogens are
      # missing (Ns and Cs have missing hydrogens but they're left
      # uncharged)
      st.atoms.map(&.formal_charge).should eq [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1]

      atom = st.atoms[11]
      atom.serial.should eq 12
      atom.name.should eq "OE2"
      atom.residue.name.should eq "GLU"
      atom.chain.id.should eq 'A'
      atom.residue.number.should eq 2
      # atom.insertion_code.should be_nil
      atom.coords.should eq [-1.204, 4.061, 0.195]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 0
      atom.element.oxygen?.should be_true
      atom.formal_charge.should eq -1
    end

    it "parses a PDB file without elements" do
      st = load_file "no_elements.pdb"
      st.atoms.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without elements and irregular line width (77)" do
      st = load_file "no_elements_irregular_end.pdb"
      st.atoms.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges" do
      st = load_file "no_charges.pdb"
      st.atoms.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges and irregular line width (79)" do
      st = load_file "no_charges_irregular_end.pdb"
      st.atoms.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.formal_charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without trailing spaces" do
      st = load_file "no_trailing_spaces.pdb"
      st.atoms.size.should eq 6
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
      st.atoms.size.should eq 6
      st.atoms.map(&.serial).should eq (99995..100000).to_a
      st.residues.map(&.number).should eq [9999, 10000]
    end

    it "parses a PDB file with unit cell parameters" do
      structure = load_file "1crn.pdb"
      cell = structure.cell?.should_not be_nil
      cell.size.should eq [40.960, 18.650, 22.520]
      cell.angles.should eq({90, 90.77, 90})
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
      structure = Chem::Structure.from_pdb IO::Memory.new <<-PDB
        HEADER    CHAPERONE                               14-FEB-13   4J7Z
        TITLE     THERMUS THERMOPHILUS DNAJ J- AND G/F-DOMAINS
        EXPDTA    X-RAY DIFFRACTION; EPR
        ATOM      1  N   ALA A   1       5.606   4.546  11.941  1.00  3.73           N
        ATOM      2  CA  ALA A   1       5.598   5.767  11.082  1.00  3.56           C
        ATOM      3  C   ALA A   1       6.441   5.527   9.850  1.00  4.13           C
        ATOM      4  O   ALA A   1       6.052   5.933   8.744  1.00  4.36           O
        ATOM      5  CB  ALA A   1       6.022   6.977  11.891  1.00  4.80           C
        PDB
      structure.experiment.should_not be_nil
      expt = structure.experiment.not_nil!
      expt.method.x_ray_diffraction?.should be_true
    end

    it "parses a PDB file with anisou/ter records" do
      st = load_file "anisou.pdb"
      st.atoms.size.should eq 133
      st.residues.map(&.number).should eq (32..52).to_a
    end

    it "parses a PDB file with deuterium" do
      st = load_file "isotopes.pdb"
      st.atoms.size.should eq 12
      st.atoms[5].element.should eq Chem::PeriodicTable::H
    end

    it "raises on unknown element X (ASX case)" do
      expect_raises Chem::ParseException, "Unknown element" do
        load_file "3e2o.pdb"
      end
    end

    it "parses a PDB file with SIG* records" do
      st = load_file "1etl.pdb"
      st.atoms.size.should eq 160
      st.residues[serial: 6]["SG"].bonded?(st.residues[serial: 14]["SG"]).should be_true
    end

    it "parses secondary structure information" do
      st = load_file "1crn.pdb"
      st.residues[0].sec.code.should eq 'E'
      st.residues[1].sec.code.should eq 'E'
      st.residues[3].sec.code.should eq 'E'
      st.residues[4].sec.code.should eq '0'
      st.residues[5].sec.code.should eq '0'
      st.residues[6].sec.code.should eq 'H'
      st.residues[18].sec.code.should eq 'H'
      st.residues[19].sec.code.should eq '0'
      st.residues[31].sec.code.should eq 'E'
      st.residues[-1].sec.code.should eq '0'
    end

    it "parses secondary structure information with insertion codes" do
      st = load_file "secondary_structure_inscode.pdb"
      st.residues.map(&.sec.code).should eq "HHHHHH000000EEEHH000".chars
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
      models = Array(Chem::Structure).from_pdb spec_file("models.pdb")
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
      structure.residues.size.should eq 1
      structure.atoms.size.should eq 8
      structure.atoms.map(&.occupancy).uniq.to_a.should eq [1, 0.37]
      structure['A'][1]["N"].x.should eq 7.831
      structure['A'][1]["OD1"].x.should eq 10.427
    end

    it "parses alternate conformations with different residues" do
      structure = load_file "alternate_conf_mut.pdb"
      structure.residues.size.should eq 1
      structure.atoms.size.should eq 14
      structure.atoms.map(&.occupancy).uniq.to_a.should eq [0.56]
      structure['A'][1].name.should eq "TRP"
      structure['A'][1]["N"].coords.should eq [3.298, 2.388, 22.684]
    end

    it "parses selected alternate conformation" do
      structure = Chem::Structure.from_pdb spec_file("alternate_conf_mut.pdb"), alt_loc: 'B'
      structure.residues.size.should eq 1
      structure.atoms.size.should eq 11
      structure.atoms.map(&.occupancy).uniq.to_a.should eq [0.22]
      structure['A'][1].name.should eq "ARG"
      structure['A'][1]["CB"].coords.should eq [4.437, 2.680, 20.555]
    end

    it "parses insertion codes" do
      residues = load_file("insertion_codes.pdb").residues
      residues.size.should eq 7
      residues.map(&.number).should eq [75, 75, 75, 75, 75, 75, 76]
      residues.map(&.insertion_code).should eq [nil, 'A', 'B', 'C', 'D', 'E', nil]
    end

    it "parses multiple models" do
      st_list = Array(Chem::Structure).from_pdb spec_file("models.pdb")
      st_list.size.should eq 4
      xs = {5.606, 7.212, 5.408, 22.055}
      st_list.zip(xs) do |st, x|
        st.source_file.should eq Path[spec_file("models.pdb")].expand
        st.atoms.size.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "parses selected models" do
      path = spec_file("models.pdb")
      st_list = Array(Chem::Structure).from_pdb path, indexes: [1, 3]
      st_list.size.should eq 2
      xs = {7.212, 22.055}
      st_list.zip(xs) do |st, x|
        st.atoms.size.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "skip models" do
      Chem::PDB::Reader.open(spec_file("models.pdb")) do |reader|
        reader.skip_entry
        reader.read_entry.atoms[0].coords.should eq [7.212, 15.334, 0.966]
        reader.skip_entry
        reader.read_entry.atoms[0].coords.should eq [22.055, 14.701, 7.032]
      end
    end

    it "parses selected chains" do
      structure = Chem::Structure.from_pdb spec_file("5jqf.pdb"), chains: ['B']
      structure.chains.size.should eq 1
      structure.residues.size.should eq 38
      structure.atoms.size.should eq 310
      structure.chains.map(&.id).should eq ['B']
      structure['B'][18].sec.code.should eq 'E'
    end

    it "parses only protein" do
      structure = Chem::Structure.from_pdb spec_file("5jqf.pdb"), het: false
      structure.chains.size.should eq 2
      structure.residues.size.should eq 42
      structure.atoms.size.should eq 586
    end

    it "parses file without the END record" do
      st = load_file "no_end.pdb"
      st.atoms.size.should eq 6
      st.chains.map(&.id).should eq ['A']
      st.residues.map(&.number).should eq [0]
      st.residues.map(&.name).should eq ["SER"]
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG"]
    end

    it "parses 1cbn (alternate conformations)" do
      structure = load_file "1cbn.pdb"
      structure.atoms.size.should eq 644
      structure.chains.size.should eq 1
      structure.residues.size.should eq 47
      structure.residues.map(&.number).should eq((1..46).to_a << 66)

      residue = structure['A'][22]
      residue.name.should eq "PRO"
      residue.atoms.size.should eq 14
      residue.atoms.map(&.occupancy).uniq.should eq [0.6]

      residue = structure['A'][23]
      residue.atoms.size.should eq 15
      residue.atoms.map(&.occupancy).uniq.should eq [1, 0.8]
      residue["CG"].coords.should eq [10.387, 12.021, 0.058]
    end

    it "parses 1dpo (insertions)" do
      st = load_file "1dpo.pdb"
      st.atoms.size.should eq 1921
      st.chains.size.should eq 1
      st.residues.size.should eq 446

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
      Chem::Structure.from_pdb spec_file("1crn.pdb"), chains: ['C']
    end

    it "parses first chain" do
      structure = Chem::Structure.from_pdb spec_file("multiple_chains.pdb"), chains: "first"
      structure.chains.size.should eq 1
      structure.residues.size.should eq 2
      structure.atoms.size.should eq 14
      structure.chains[0].id.should eq 'J'
    end

    it "parses left-justified element (#84)" do
      io = IO::Memory.new <<-PDB
        ATOM      1  N   GLY     1     -20.286 -37.665  -6.811  1.00  0.00          N
        ATOM      2  H1  GLY     1     -20.247 -38.062  -5.872  1.00  0.00          H
        ATOM      3  H2  GLY     1     -20.074 -36.616  -6.704  1.00  0.00          H
        ATOM      4  H3  GLY     1     -21.301 -37.774  -7.185  1.00  0.00          H
        ATOM      5  CA  GLY     1     -19.299 -38.321  -7.682  1.00  0.00          C
        PDB
      s = Chem::Structure.from_pdb io
      s.atoms.map(&.element.symbol).should eq %w(N H H H C)
    end

    it "parses a PDB header" do
      expt = Chem::Structure::Experiment.from_pdb spec_file("1crn.pdb")
      expt.deposition_date.should eq Time.utc(1981, 4, 30)
      expt.doi.should eq "10.1073/PNAS.81.19.6014"
      expt.method.x_ray_diffraction?.should be_true
      expt.pdb_accession.should eq "1CRN"
      expt.resolution.should eq 1.5
      expt.title.should eq "WATER STRUCTURE OF A HYDROPHOBIC PROTEIN AT ATOMIC \
                            RESOLUTION. PENTAGON RINGS OF WATER MOLECULES IN CRYSTALS \
                            OF CRAMBIN"
    end

    it "reads jumping resids" do
      structure = load_file "1a02_1.pdb"
      structure.dig('B').residues.map(&.number).should eq(
        (5001..5020).to_a +
        [6004, 6012, 6014, 6031, 6032, 6033, 6037, 6038, 6039, 6041, 6042, 6047,
         6051, 6054, 6061, 6066, 6080, 6088])
      structure.dig('F').residues.map(&.number).should eq(
        (140..192).to_a + [6010, 6044, 6064])
    end

    it "discards empty remark 2 record" do
      expt = Chem::Structure::Experiment.from_pdb spec_file("1a02_1.pdb")
      expt.resolution.should eq 2.7
    end

    it "raises if unit cell is invalid" do
      io = IO::Memory.new <<-PDB
        CRYST1   40.960   18.650   22.520  90.00  90.77 -90.00 P 1 21 1
        PDB
      ex = expect_raises Chem::ParseException, "Invalid cell angle gamma" do
        Chem::Structure::Experiment.from_pdb io
      end
      ex.inspect_with_location.should eq <<-PDB
        Found a parsing issue:

         1 | CRYST1   40.960   18.650   22.520  90.00  90.77 -90.00 P 1 21 1
                                                            ^^^^^^^
        Error: Invalid cell angle gamma
        PDB
    end

    it "ignores alternate conformation if occupancy is one" do
      structure = Chem::Structure.from_pdb spec_file("3h31.pdb"), alt_loc: 'A'
      # N is in alternate conformation B only but it has occupancy = 1
      structure.dig('A', 33, "N").serial.should eq 285
    end

    it "sets cell to nil if default values (#161)" do
      io = IO::Memory.new <<-PDB
        CRYST1    1.000    1.000    1.000  90.00  90.00  90.00 P 1 21 1
        ATOM      1  N   THR A   1      17.047  14.099   3.625  1.00 13.79           N
        PDB
      Chem::Structure.from_pdb(io).cell?.should be_nil
    end

    it "parses a truncated PDB without occupancy" do
      structure = load_file "DTD.pdb"
      structure.atoms.size.should eq 16
      structure.bonds.size.should eq 16
    end

    it "parses zero-sized cell as nil (#189)" do
      io = IO::Memory.new <<-PDB
        CRYST1    0.000    0.000    0.000  90.00  90.00  90.00 P 1           1
        ATOM      1  N   SER A   0      14.353  62.634  39.550  1.00 48.24           N
        PDB
      Chem::Structure.from_pdb(io).cell?.should be_nil
    end

    it "parses one-sized cell as nil" do
      io = IO::Memory.new <<-PDB
        CRYST1    1.000    1.000    1.000  90.00  90.00  90.00 P 1           1
        ATOM      1  N   SER A   0      14.353  62.634  39.550  1.00 48.24           N
        PDB
      Chem::Structure.from_pdb(io).cell?.should be_nil
    end

    it "raises on invalid cell parameters" do
      io = IO::Memory.new <<-PDB
        CRYST1   31.000    0.000   11.000  90.00 120.00  90.00 P 1           1
        ATOM      1  N   SER A   0      14.353  62.634  39.550  1.00 48.24           N
        PDB
      expect_raises(Chem::ParseException, "Invalid cell parameters") do
        Chem::Structure.from_pdb(io).cell?.should be_nil
      end
    end

    it "ignores empty REMARK (#222)" do
      content = <<-PDB
        HEADER 
        TITLE     Built with Packmol                                             
        REMARK   Packmol generated pdb file 
        REMARK   Home-Page: http://m3g.iqm.unicamp.br/packmol
        REMARK
        HETATM    1  C1  LIG A   1      -0.463  -1.344   0.002  0.00  1.00           C  
        HETATM    2  C2  LIG A   1      -1.369  -0.309   0.001  0.00  1.00           C  
        HETATM    3  C3  LIG A   1      -0.895   1.105  -0.002  0.00  1.00           C
        PDB
      struc = Chem::Structure.from_pdb IO::Memory.new(content)
      struc.title.should eq "Built with Packmol"
      struc.experiment.should be_nil
      struc.atoms.map(&.name).should eq %w(C1 C2 C3)
    end
  end
end

describe Chem::PDB::Writer do
  it "writes a structure" do
    structure = load_file "1crn.pdb"
    expected = File.read spec_file("1crn--stripped.pdb")
    structure.to_pdb(bonds: :none).should eq expected
  end

  it "writes atoms" do
    structure = load_file "1crn.pdb"
    structure.residues[4].atoms.to_pdb.should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      ATOM      1  N   PRO A   5       9.561   9.108  13.563  1.00  3.96           N  |
      ATOM      2  CA  PRO A   5       9.448   9.034  15.012  1.00  4.25           C  |
      ATOM      3  C   PRO A   5       9.288   7.670  15.606  1.00  4.96           C  |
      ATOM      4  O   PRO A   5       9.490   7.519  16.819  1.00  7.44           O  |
      ATOM      5  CB  PRO A   5       8.230   9.957  15.345  1.00  5.11           C  |
      ATOM      6  CG  PRO A   5       7.338   9.786  14.114  1.00  5.24           C  |
      ATOM      7  CD  PRO A   5       8.366   9.804  12.958  1.00  5.20           C  |
      END                                                                             |\n
      PDB
  end

  it "writes ter records at the end of polymer chains" do
    content = File.read spec_file("5e5v.pdb")
    structure = Chem::Structure.from_pdb IO::Memory.new(content), guess_bonds: true
    structure.to_pdb.should eq content
  end

  it "keeps original atom numbering" do
    structure = load_file "1crn.pdb"
    structure.residues[4].atoms.to_pdb(renumber: false).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      ATOM     27  N   PRO A   5       9.561   9.108  13.563  1.00  3.96           N  |
      ATOM     28  CA  PRO A   5       9.448   9.034  15.012  1.00  4.25           C  |
      ATOM     29  C   PRO A   5       9.288   7.670  15.606  1.00  4.96           C  |
      ATOM     30  O   PRO A   5       9.490   7.519  16.819  1.00  7.44           O  |
      ATOM     31  CB  PRO A   5       8.230   9.957  15.345  1.00  5.11           C  |
      ATOM     32  CG  PRO A   5       7.338   9.786  14.114  1.00  5.24           C  |
      ATOM     33  CD  PRO A   5       8.366   9.804  12.958  1.00  5.20           C  |
      END                                                                             |\n
      PDB
  end

  it "writes CONECT records" do
    structure = Chem::Structure.build do
      residue "ICN" do
        atom :i, vec3(3.149, 0, 0)
        atom :c, vec3(1.148, 0, 0)
        atom :n, vec3(0, 0, 0)

        bond "I1", "C1"
        bond "C1", "N1", :triple
      end
    end

    structure.to_pdb(bonds: :all).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  I1  ICN A   1       3.149   0.000   0.000  1.00  0.00           I  |
      HETATM    2  C1  ICN A   1       1.148   0.000   0.000  1.00  0.00           C  |
      HETATM    3  N1  ICN A   1       0.000   0.000   0.000  1.00  0.00           N  |
      CONECT    1    2                                                                |
      CONECT    2    1    3    3    3                                                 |
      CONECT    3    2    2    2                                                      |
      END                                                                             |\n
      PDB
  end

  it "writes CONECT records for renumbered atoms" do
    structure = Chem::Structure.build do
      residue "ICN" do
        atom :i, vec3(3.149, 0, 0)
        atom :c, vec3(1.148, 0, 0)
        atom :n, vec3(0, 0, 0)

        bond "I1", "C1"
        bond "C1", "N1", :triple
      end

      residue "ICN" do
        atom :i, vec3(13.149, 0, 0)
        atom :c, vec3(11.148, 0, 0)
        atom :n, vec3(10, 0, 0)

        bond "I1", "C1"
        bond "C1", "N1", :triple
      end
    end

    structure.residues[1].atoms.to_pdb(bonds: :all).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  I1  ICN A   2      13.149   0.000   0.000  1.00  0.00           I  |
      HETATM    2  C1  ICN A   2      11.148   0.000   0.000  1.00  0.00           C  |
      HETATM    3  N1  ICN A   2      10.000   0.000   0.000  1.00  0.00           N  |
      CONECT    1    2                                                                |
      CONECT    2    1    3    3    3                                                 |
      CONECT    3    2    2    2                                                      |
      END                                                                             |\n
      PDB
  end

  it "writes big numbers" do
    structure = Chem::Structure.build do
      residue "ICN" do
        atom :i, vec3(3.149, 0, 0)
        atom :c, vec3(1.148, 0, 0)
        atom :n, vec3(0, 0, 0)

        bond "I1", "C1"
        bond "C1", "N1", :triple
      end
    end
    structure.atoms[0].serial = 99_999
    structure.atoms[1].serial = 100_000
    structure.atoms[2].serial = 235_123
    structure.residues[0].number = 10_231

    structure.to_pdb(bonds: :all, renumber: false).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM99999  I1  ICN AA06F       3.149   0.000   0.000  1.00  0.00           I  |
      HETATMA0000  C1  ICN AA06F       1.148   0.000   0.000  1.00  0.00           C  |
      HETATMA2W9F  N1  ICN AA06F       0.000   0.000   0.000  1.00  0.00           N  |
      CONECT99999A0000                                                                |
      CONECTA000099999A2W9FA2W9FA2W9F                                                 |
      CONECTA2W9FA0000A0000A0000                                                      |
      END                                                                             |\n
      PDB
  end

  it "writes four-letter residue names (#45)" do
    structure = Chem::Structure.build(guess_bonds: true) do
      residue "DMPG" do
        atom "C13", vec3(9.194, 10.488, 13.865)
        atom "H13A", vec3(8.843, 9.508, 14.253)
        atom "H13B", vec3(10.299, 10.527, 13.756)
        atom "OC3", vec3(8.600, 10.828, 12.580)
      end
    end
    structure.to_pdb(bonds: :none).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  C13 DMPGA   1       9.194  10.488  13.865  1.00  0.00           C1-|
      HETATM    2 H13A DMPGA   1       8.843   9.508  14.253  1.00  0.00           H  |
      HETATM    3 H13B DMPGA   1      10.299  10.527  13.756  1.00  0.00           H  |
      HETATM    4  OC3 DMPGA   1       8.600  10.828  12.580  1.00  0.00           O1-|
      END                                                                             |\n
      PDB
  end

  it "writes multiple entries" do
    path = spec_file("models.pdb")
    entries = Array(Chem::Structure).from_pdb path
    entries.to_pdb.should eq File.read(path).gsub(/CONECT.+\n/, "")
  end

  it "writes an indeterminate number of entries" do
    path = spec_file("models.pdb")
    entries = Array(Chem::Structure).from_pdb path

    io = IO::Memory.new
    Chem::PDB::Writer.open(io) do |writer|
      entries.each do |entry|
        writer << entry
      end
    end
    io.to_s.should eq File.read(path).gsub(/(NUMMDL|CONECT).+\n/, "")
  end

  it "aligns the unit cell to the xy-plane" do
    structure = load_file "5e5v--unwrapped.poscar"
    structure = Chem::Structure.from_pdb IO::Memory.new(structure.to_pdb)
    structure.atoms[0].coords.should be_close [8.128, 2.297, 11.112], 1e-3
    structure.atoms[167].coords.should be_close [11.0, 6.405, 12.834], 1e-3
  end

  it "writes CONECT records for disulfide bridges and HET groups by default" do
    pdb_content = load_file("1cbn.pdb").to_pdb(renumber: false)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq <<-PDB.delete('|')
      CONECT   44  685                                                                |
      CONECT   54  566                                                                |
      CONECT  269  477                                                                |
      CONECT  477  269                                                                |
      CONECT  566   54                                                                |
      CONECT  685   44                                                                |
      CONECT  774  775  777                                                           |
      CONECT  775  774                                                                |
      CONECT  777  774                                                                |
      PDB
  end

  it "writes CONECT records for standard residues only" do
    structure = load_file("AlaIle--unwrapped.poscar", guess_bonds: true, guess_names: true)
    pdb_content = structure.to_pdb(bonds: :standard)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq <<-PDB.delete('|')
      CONECT    1    2    3    4                                                      |
      CONECT    2    1                                                                |
      CONECT    3    1                                                                |
      CONECT    4    1    5    6    8                                                 |
      CONECT    5    4                                                                |
      CONECT    6    4    7    7   12                                                 |
      CONECT    7    6    6                                                           |
      CONECT    8    4    9   10   11                                                 |
      CONECT    9    8                                                                |
      CONECT   10    8                                                                |
      CONECT   11    8                                                                |
      CONECT   12    6   13   14                                                      |
      CONECT   13   12                                                                |
      CONECT   14   12   15   16   20                                                 |
      CONECT   15   14                                                                |
      CONECT   16   14   17   17   18                                                 |
      CONECT   17   16   16                                                           |
      CONECT   18   16   19                                                           |
      CONECT   19   18                                                                |
      CONECT   20   14   21   22   29                                                 |
      CONECT   21   20                                                                |
      CONECT   22   20   23   24   25                                                 |
      CONECT   23   22                                                                |
      CONECT   24   22                                                                |
      CONECT   25   22   26   27   28                                                 |
      CONECT   26   25                                                                |
      CONECT   27   25                                                                |
      CONECT   28   25                                                                |
      CONECT   29   20   30   31   32                                                 |
      CONECT   30   29                                                                |
      CONECT   31   29                                                                |
      CONECT   32   29                                                                |
      PDB
  end

  it "writes CONECT records for disulfide bridges only" do
    expected = File.read(spec_file("1crn.pdb")).lines.select(/^CONECT/).join('\n')
    pdb_content = load_file("1crn.pdb").to_pdb(bonds: :disulfide)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq expected
  end

  it "writes CONECT records for HET groups only" do
    pdb_content = load_file("1cbn.pdb").to_pdb(bonds: :het, renumber: false)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq <<-PDB.delete('|')
      CONECT  774  775  777                                                           |
      CONECT  775  774                                                                |
      CONECT  777  774                                                                |
      PDB
  end

  it "does not write CONECT records for water residues if bonds is HET" do
    structure = load_file("waters.xyz", guess_bonds: true, guess_names: true)
    pdb_content = structure.to_pdb(bonds: :het)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq ""
  end

  it "writes CONECT records for water residues if bonds is standard" do
    structure = load_file("waters.xyz", guess_bonds: true, guess_names: true)
    pdb_content = structure.to_pdb(bonds: :standard)
    pdb_content.lines.select(/^CONECT/).join('\n').should eq <<-PDB.delete('|')
      CONECT    1    2    3                                                           |
      CONECT    2    1                                                                |
      CONECT    3    1                                                                |
      CONECT    4    5    6                                                           |
      CONECT    5    4                                                                |
      CONECT    6    4                                                                |
      CONECT    7    8    9                                                           |
      CONECT    8    7                                                                |
      CONECT    9    7                                                                |
      PDB
  end

  it "writes TER per each fragment (#89)" do
    structure = load_file("waters.xyz", guess_bonds: true, guess_names: true)
    structure.to_pdb(ter_on_fragment: true).should eq <<-PDB.delete('|')
      TITLE     Three waters                                                          |
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  O   HOH A   1       2.336   3.448   7.781  1.00  0.00           O  |
      HETATM    2  H1  HOH A   1       1.446   3.485   7.315  1.00  0.00           H  |
      HETATM    3  H2  HOH A   1       2.977   2.940   7.234  1.00  0.00           H  |
      TER       4      HOH A   1                                                      |
      HETATM    5  O   HOH A   2      11.776  11.590   8.510  1.00  0.00           O  |
      HETATM    6  H1  HOH A   2      12.756  11.588   8.379  1.00  0.00           H  |
      HETATM    7  H2  HOH A   2      11.395  11.031   7.787  1.00  0.00           H  |
      TER       8      HOH A   2                                                      |
      HETATM    9  O   HOH A   3       6.015  11.234   7.771  1.00  0.00           O  |
      HETATM   10  H1  HOH A   3       6.440  12.040   7.394  1.00  0.00           H  |
      HETATM   11  H2  HOH A   3       6.738  10.850   8.321  1.00  0.00           H  |
      TER      12      HOH A   3                                                      |
      END                                                                             |

      PDB
  end

  it "writes TER per each fragment for a view (#89)" do
    structure = load_file("waters.xyz", guess_bonds: true, guess_names: true)
    structure.atoms.to_pdb(ter_on_fragment: true).should eq <<-PDB.delete('|')
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  O   HOH A   1       2.336   3.448   7.781  1.00  0.00           O  |
      HETATM    2  H1  HOH A   1       1.446   3.485   7.315  1.00  0.00           H  |
      HETATM    3  H2  HOH A   1       2.977   2.940   7.234  1.00  0.00           H  |
      TER       4      HOH A   1                                                      |
      HETATM    5  O   HOH A   2      11.776  11.590   8.510  1.00  0.00           O  |
      HETATM    6  H1  HOH A   2      12.756  11.588   8.379  1.00  0.00           H  |
      HETATM    7  H2  HOH A   2      11.395  11.031   7.787  1.00  0.00           H  |
      TER       8      HOH A   2                                                      |
      HETATM    9  O   HOH A   3       6.015  11.234   7.771  1.00  0.00           O  |
      HETATM   10  H1  HOH A   3       6.440  12.040   7.394  1.00  0.00           H  |
      HETATM   11  H2  HOH A   3       6.738  10.850   8.321  1.00  0.00           H  |
      TER      12      HOH A   3                                                      |
      END                                                                             |

      PDB
  end

  it "writes correct numbers in CONECT with TER" do
    structure = load_file("waters.xyz", guess_bonds: true, guess_names: true)
    structure.to_pdb(bonds: :all, ter_on_fragment: true).should eq <<-PDB.delete('|')
      TITLE     Three waters                                                          |
      REMARK   4                                                                      |
      REMARK   4      COMPLIES WITH FORMAT V. 3.30, 13-JUL-11                         |
      HETATM    1  O   HOH A   1       2.336   3.448   7.781  1.00  0.00           O  |
      HETATM    2  H1  HOH A   1       1.446   3.485   7.315  1.00  0.00           H  |
      HETATM    3  H2  HOH A   1       2.977   2.940   7.234  1.00  0.00           H  |
      TER       4      HOH A   1                                                      |
      HETATM    5  O   HOH A   2      11.776  11.590   8.510  1.00  0.00           O  |
      HETATM    6  H1  HOH A   2      12.756  11.588   8.379  1.00  0.00           H  |
      HETATM    7  H2  HOH A   2      11.395  11.031   7.787  1.00  0.00           H  |
      TER       8      HOH A   2                                                      |
      HETATM    9  O   HOH A   3       6.015  11.234   7.771  1.00  0.00           O  |
      HETATM   10  H1  HOH A   3       6.440  12.040   7.394  1.00  0.00           H  |
      HETATM   11  H2  HOH A   3       6.738  10.850   8.321  1.00  0.00           H  |
      TER      12      HOH A   3                                                      |
      CONECT    1    2    3                                                           |
      CONECT    2    1                                                                |
      CONECT    3    1                                                                |
      CONECT    5    6    7                                                           |
      CONECT    6    5                                                                |
      CONECT    7    5                                                                |
      CONECT    9   10   11                                                           |
      CONECT   10    9                                                                |
      CONECT   11    9                                                                |
      END                                                                             |\n
      PDB
  end
end
