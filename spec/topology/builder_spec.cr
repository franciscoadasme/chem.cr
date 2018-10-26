require "../../spec_helper"

describe Chem::System::Builder do
  it "builds a system" do
    sys = Chem::System::Builder.build do
      title "Ser-Thr-Gly Val"
      chain 'F' do
        residue "SER", 1 do
          atom "N", {10.761, 7.798, 14.008}
          atom "CA", {11.332, 7.135, 15.151}
          atom "C", {10.293, 6.883, 16.240}
          atom "O", {9.831, 7.812, 16.932}
          atom "CB", {12.486, 8.009, 15.664}
          atom "OG", {12.863, 7.872, 17.046}
        end
        residue "THR", 2 do
          atom "N", {9.905, 5.621, 16.468}
          atom "CA", {8.911, 5.306, 17.473}
          atom "C", {9.309, 5.682, 18.870}
          atom "O", {8.414, 5.905, 19.663}
          atom "CB", {8.583, 3.831, 17.460}
          atom "OG1", {9.767, 3.088, 17.284}
          atom "CG2", {7.681, 3.521, 16.314}
        end
        residue "GLY", 3 do
          atom "N", {10.580, 5.793, 19.220}
          atom "CA", {10.958, 6.188, 20.552}
          atom "C", {10.749, 7.689, 20.740}
          atom "O", {10.201, 8.174, 21.744}
        end
      end
      chain 'G' do
        residue "VAL", 1 do
          atom "N", {18.066, -7.542, 27.177}
          atom "CA", {17.445, -8.859, 27.179}
          atom "C", {16.229, -8.870, 26.253}
          atom "O", {16.058, -9.815, 25.479}
          atom "CB", {17.045, -9.235, 28.617}
          atom "CG1", {16.407, -10.621, 28.678}
          atom "CG2", {18.300, -9.262, 29.461}
        end
      end
    end

    sys.title.should eq "Ser-Thr-Gly Val"

    sys.chains.size.should eq 2
    sys.chains.map(&.id).should eq ['F', 'G']

    sys.residues.size.should eq 4
    sys.residues.map(&.chain.id).should eq ['F', 'F', 'F', 'G']
    sys.residues.map(&.number).should eq [1, 2, 3, 1]
    sys.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    sys.residues.map(&.atoms.size).should eq [6, 7, 4, 7]

    sys.size.should eq 24
    sys.atoms.map(&.serial).should eq (1..24).to_a
    sys.atoms[0..6].map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG", "N"]
    sys.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    sys.atoms.map(&.chain.id).should eq ("F" * 17 + "G" * 7).chars
    sys.atoms[serial: 13].x.should eq 7.681
  end

  it "builds a system (no DSL)" do
    builder = Chem::System::Builder.new
    builder.title "Ser-Thr-Gly Val"
    builder.chain 'T'
    builder.residue "SER"
    builder.atom "N", {10.761, 7.798, 14.008}
    builder.residue "THR"
    builder.atom "N", {9.905, 5.621, 16.468}
    builder.residue "GLY"
    builder.atom "N", {10.580, 5.793, 19.220}
    builder.chain 'U'
    builder.residue "VAL"
    builder.atom "N", {18.066, -7.542, 27.177}

    sys = builder.build

    sys.title.should eq "Ser-Thr-Gly Val"
    sys.chains.map(&.id).should eq ['T', 'U']
    sys.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    sys.residues.map(&.number).should eq [1, 2, 3, 1]
    sys.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    sys.atoms[serial: 4].x.should eq 18.066
  end

  it "builds a system with alternate conformations" do
    sys = Chem::System::Builder.build do
      chain do
        residue do
          atom "N", {7.831, -27.902, 17.508}
          atom "C", {6.189, -26.986, 15.988}
          atom "O", {5.359, -27.732, 16.505}

          conf 'A', 0.65 do
            atom "CB", {7.668, -27.218, 16.232}
            atom "CG", {9.718, -27.932, 14.926}
          end

          conf 'B', 0.2 do
            atom "CB", {7.629, -26.946, 16.449}
            atom "CG", {8.451, -28.477, 14.616}
          end

          conf 'C', 0.15 do
            atom "CB", {7.671, -27.217, 16.251}
            atom "CG", {9.113, -27.299, 14.210}
          end

          atom "CD", {8.226, -28.074, 15.091}
        end
      end
    end

    sys.atoms.map(&.alt_loc).should eq [nil, nil, nil, 'A', 'A', nil]
    sys.residues.first.conformations.map(&.id).should eq ['A', 'B', 'C']
  end

  it "builds a system with lattice" do
    sys = Chem::System::Builder.build do
      lattice do
        a Vector[25.0, 32.0, 12.0]
        b Vector[12.0, 34.0, 23.0]
        c Vector[12.0, 68.0, 21.0]
        scale by: 1.1
        space_group "P 1 2 1"
      end
    end

    lat = sys.lattice.not_nil!
    lat.a.should eq Vector[25, 32, 12]
    lat.b.should eq Vector[12, 34, 23]
    lat.c.should eq Vector[12, 68, 21]
    lat.scale_factor.should eq 1.1
    lat.space_group.should eq "P 1 2 1"
  end

  it "builds a system with lattice using numbers" do
    sys = Chem::System::Builder.build do
      lattice do
        a 25
        b 34
        c 21
      end
    end

    lat = sys.lattice.not_nil!
    lat.a.should eq Vector[25, 0, 0]
    lat.b.should eq Vector[0, 34, 0]
    lat.c.should eq Vector[0, 0, 21]
  end

  it "builds a system with lattice using numbers (one-line)" do
    sys = Chem::System::Builder.build do
      lattice 25, 34, 21
    end

    lat = sys.lattice.not_nil!
    lat.a.should eq Vector[25, 0, 0]
    lat.b.should eq Vector[0, 34, 0]
    lat.c.should eq Vector[0, 0, 21]
  end

  it "names chains automatically" do
    sys = Chem::System::Builder.build do
      5.times { chain }
    end

    sys.chains.map(&.id).should eq ['A', 'B', 'C', 'D', 'E']
  end

  it "names chains automatically after manually setting one" do
    sys = Chem::System::Builder.build do
      chain 'F'
      chain
      chain
    end

    sys.chains.map(&.id).should eq ['F', 'G', 'H']
  end

  it "numbers residues automatically" do
    sys = Chem::System::Builder.build do
      chain
      2.times { residue "ALA" }
      chain
      5.times { residue "GLY" }
      chain
      3.times { residue "PRO" }
    end

    sys.residues.map(&.number).should eq [1, 2, 1, 2, 3, 4, 5, 1, 2, 3]
  end

  it "numbers residues automatically after manually setting one" do
    sys = Chem::System::Builder.build do
      chain
      residue "SER", 5
      3.times { residue "ALA" }
    end

    sys.residues.map(&.number).should eq [5, 6, 7, 8]
  end

  it "names atoms automatically when called with element" do
    sys = Chem::System::Builder.build do
      atom PeriodicTable::C
      atom PeriodicTable::C
      atom PeriodicTable::O
      atom PeriodicTable::N
      atom PeriodicTable::C
      atom PeriodicTable::N
    end

    sys.atoms.map(&.name).should eq ["C1", "C2", "O1", "N1", "C3", "N2"]
  end

  it "creates a chain automatically" do
    sys = Chem::System::Builder.build do
      residue "SER"
    end

    sys.chains.map(&.id).should eq ['A']
  end

  it "creates a residue automatically" do
    sys = Chem::System::Builder.build do
      atom "CA"
    end

    sys.chains.map(&.id).should eq ['A']
    sys.residues.map(&.number).should eq [1]
    sys.residues.map(&.name).should eq ["UNK"]
  end

  it "adds dummy atoms" do
    sys = Chem::System::Builder.build do
      atoms "N", "CA", "C", "O", "CB"
    end

    sys.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    sys.atoms.all?(&.coords.zero?).should be_true
  end

  it "adds dummy atoms with coordinates" do
    sys = Chem::System::Builder.build do
      atom at: {1, 0, 0}
      atom at: {2, 0, 0}
    end

    sys.atoms.map(&.name).should eq ["C1", "C2"]
    sys.atoms.map(&.x).should eq [1, 2]
  end

  it "adds atom with named arguments" do
    sys = Chem::System::Builder.build do
      atom "OD1", charge: -1, temperature_factor: 43.24
    end

    atom = sys.atoms[-1]
    atom.charge.should eq -1
    atom.temperature_factor.should eq 43.24
  end
end
