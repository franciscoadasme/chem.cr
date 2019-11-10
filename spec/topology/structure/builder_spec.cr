require "../../spec_helper"

describe Chem::Topology::Builder do
  it "builds a structure" do
    st = Chem::Topology::Builder.build do
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
    builder = Chem::Topology::Builder.new
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
    st = Chem::Topology::Builder.build do
      lattice V[25, 32, 12], V[12, 34, 23], V[12, 68, 21]
    end

    lat = st.lattice.not_nil!
    lat.a.should eq Vector[25, 32, 12]
    lat.b.should eq Vector[12, 34, 23]
    lat.c.should eq Vector[12, 68, 21]
  end

  it "builds a structure with lattice using numbers" do
    st = Chem::Topology::Builder.build do
      lattice 25, 34, 21
    end

    lat = st.lattice.not_nil!
    lat.a.should eq Vector[25, 0, 0]
    lat.b.should eq Vector[0, 34, 0]
    lat.c.should eq Vector[0, 0, 21]
  end

  it "builds a structure with lattice using numbers (one-line)" do
    st = Chem::Topology::Builder.build do
      lattice 25, 34, 21
    end

    lat = st.lattice.not_nil!
    lat.a.should eq Vector[25, 0, 0]
    lat.b.should eq Vector[0, 34, 0]
    lat.c.should eq Vector[0, 0, 21]
  end

  it "names chains automatically" do
    st = Chem::Topology::Builder.build do
      5.times do
        chain { }
      end
    end

    st.chains.map(&.id).should eq ['A', 'B', 'C', 'D', 'E']
  end

  it "names chains automatically after manually setting one" do
    st = Chem::Topology::Builder.build do
      chain 'F'
      chain { }
      chain { }
    end

    st.chains.map(&.id).should eq ['F', 'G', 'H']
  end

  it "numbers residues automatically" do
    st = Chem::Topology::Builder.build do
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
    st = Chem::Topology::Builder.build do
      chain
      residue "SER", 5
      3.times { residue "ALA" }
    end

    st.residues.map(&.number).should eq [5, 6, 7, 8]
  end

  it "names atoms automatically when called with element" do
    st = Chem::Topology::Builder.build do
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
    st = Chem::Topology::Builder.build do
      residue "SER"
    end

    st.chains.map(&.id).should eq ['A']
  end

  it "creates a residue automatically" do
    st = Chem::Topology::Builder.build do
      atom "CA", Vector.origin
    end

    st.chains.map(&.id).should eq ['A']
    st.residues.map(&.number).should eq [1]
    st.residues.map(&.name).should eq ["UNK"]
  end

  it "adds dummy atoms" do
    st = Chem::Topology::Builder.build do
      %w(N CA C O CB).each { |name| atom name, Vector.origin }
    end

    st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    st.atoms.all?(&.coords.zero?).should be_true
  end

  it "adds dummy atoms with coordinates" do
    st = Chem::Topology::Builder.build do
      atom V[1, 0, 0]
      atom V[2, 0, 0]
    end

    st.atoms.map(&.name).should eq ["C1", "C2"]
    st.atoms.map(&.x).should eq [1, 2]
  end

  it "adds atom with named arguments" do
    st = Chem::Topology::Builder.build do
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
end
