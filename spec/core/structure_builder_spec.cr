require "../spec_helper"

describe Chem::Structure::Builder do
  it "builds a structure" do
    st = Chem::Structure.build do
      title "Ser-Thr-Gly Val"
      chain 'F' do
        residue "SER", 1 do
          atom "N", vec3(10.761, 7.798, 14.008)
          atom "CA", vec3(11.332, 7.135, 15.151)
          atom "C", vec3(10.293, 6.883, 16.240)
          atom "O", vec3(9.831, 7.812, 16.932)
          atom "CB", vec3(12.486, 8.009, 15.664)
          atom "OG", vec3(12.863, 7.872, 17.046)
        end
        residue "THR", 2 do
          atom "N", vec3(9.905, 5.621, 16.468)
          atom "CA", vec3(8.911, 5.306, 17.473)
          atom "C", vec3(9.309, 5.682, 18.870)
          atom "O", vec3(8.414, 5.905, 19.663)
          atom "CB", vec3(8.583, 3.831, 17.460)
          atom "OG1", vec3(9.767, 3.088, 17.284)
          atom "CG2", vec3(7.681, 3.521, 16.314)
        end
        residue "GLY", 3 do
          atom "N", vec3(10.580, 5.793, 19.220)
          atom "CA", vec3(10.958, 6.188, 20.552)
          atom "C", vec3(10.749, 7.689, 20.740)
          atom "O", vec3(10.201, 8.174, 21.744)
        end
      end
      chain 'G' do
        residue "VAL", 1 do
          atom "N", vec3(18.066, -7.542, 27.177)
          atom "CA", vec3(17.445, -8.859, 27.179)
          atom "C", vec3(16.229, -8.870, 26.253)
          atom "O", vec3(16.058, -9.815, 25.479)
          atom "CB", vec3(17.045, -9.235, 28.617)
          atom "CG1", vec3(16.407, -10.621, 28.678)
          atom "CG2", vec3(18.300, -9.262, 29.461)
        end
      end
    end

    st.title.should eq "Ser-Thr-Gly Val"

    st.chains.size.should eq 2
    st.chains.map(&.id).should eq ['F', 'G']

    st.residues.size.should eq 4
    st.residues.map(&.chain.id).should eq ['F', 'F', 'F', 'G']
    st.residues.map(&.number).should eq [1, 2, 3, 1]
    st.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    st.residues.map(&.atoms.size).should eq [6, 7, 4, 7]

    st.atoms.size.should eq 24
    st.atoms.map(&.number).should eq (1..24).to_a
    st.atoms[0..6].map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG", "N"]
    st.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    st.atoms.map(&.chain.id).should eq ("F" * 17 + "G" * 7).chars
    st.atoms.find!(13).x.should eq 7.681
  end

  it "builds a structure (no DSL)" do
    builder = Chem::Structure::Builder.new
    builder.title "Ser-Thr-Gly Val"
    builder.chain 'T'
    builder.residue "SER"
    builder.atom "N", vec3(10.761, 7.798, 14.008)
    builder.residue "THR"
    builder.atom "N", vec3(9.905, 5.621, 16.468)
    builder.residue "GLY"
    builder.atom "N", vec3(10.580, 5.793, 19.220)
    builder.chain 'U'
    builder.residue "VAL"
    builder.atom "N", vec3(18.066, -7.542, 27.177)

    st = builder.build

    st.title.should eq "Ser-Thr-Gly Val"
    st.chains.map(&.id).should eq ['T', 'U']
    st.residues.map(&.name).should eq ["SER", "THR", "GLY", "VAL"]
    st.residues.map(&.number).should eq [1, 2, 3, 1]
    st.atoms.map(&.residue.name).uniq.should eq ["SER", "THR", "GLY", "VAL"]
    st.atoms.find!(4).x.should eq 18.066
  end

  it "builds a structure with cell" do
    structure = Chem::Structure.build do |builder|
      builder.cell vec3(25, 32, 12), vec3(12, 34, 23), vec3(12, 68, 21)
    end
    structure.cell.basis.should eq Chem::Spatial::Mat3.basis(
      vec3(25, 32, 12),
      vec3(12, 34, 23),
      vec3(12, 68, 21),
    )
  end

  it "builds a structure with cell using numbers" do
    structure = Chem::Structure.build &.cell(25, 34, 21)
    structure.cell.basis.should eq Chem::Spatial::Mat3.basis(
      vec3(25, 0, 0),
      vec3(0, 34, 0),
      vec3(0, 0, 21),
    )
  end

  it "builds a structure with cell using numbers (one-line)" do
    structure = Chem::Structure.build &.cell(25, 34, 21)
    structure.cell.basis.should eq Chem::Spatial::Mat3.basis(
      vec3(25, 0, 0),
      vec3(0, 34, 0),
      vec3(0, 0, 21),
    )
  end

  it "names chains automatically" do
    st = Chem::Structure.build do
      62.times do
        chain { }
      end
    end

    ids = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".chars
    st.chains.map(&.id).should eq ids
  end

  it "names chains automatically after manually setting one" do
    st = Chem::Structure.build do
      chain 'F'
      chain { }
      chain { }
    end

    st.chains.map(&.id).should eq ['F', 'G', 'H']
  end

  it "fails over chain id limit" do
    expect_raises ArgumentError, "Non-alphanumeric chain id" do
      Chem::Structure.build do
        63.times do
          chain { }
        end
      end
    end
  end

  it "numbers residues automatically" do
    st = Chem::Structure.build do
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
    st = Chem::Structure.build do
      chain
      residue "SER", 5
      3.times { residue "ALA" }
    end

    st.residues.map(&.number).should eq [5, 6, 7, 8]
  end

  it "names atoms automatically when called with element" do
    st = Chem::Structure.build do
      residue "UNK" do
        atom :C, vec3(0, 0, 0)
        atom :C, vec3(0, 0, 0)
        atom :O, vec3(0, 0, 0)
        atom :N, vec3(0, 0, 0)
        atom :C, vec3(0, 0, 0)
        atom :N, vec3(0, 0, 0)
      end

      residue "UNK" do
        atom :C, vec3(0, 0, 0)
        atom :H, vec3(0, 0, 0)
        atom :O, vec3(0, 0, 0)
        atom :P, vec3(0, 0, 0)
        atom :C, vec3(0, 0, 0)
        atom :H, vec3(0, 0, 0)
        atom :N, vec3(0, 0, 0)
      end
    end

    st.residues[0].atoms.map(&.name).should eq %w(C1 C2 O1 N1 C3 N2)
    st.residues[1].atoms.map(&.name).should eq %w(C1 H1 O1 P1 C2 H2 N1)
  end

  it "creates a chain automatically" do
    st = Chem::Structure.build do
      residue "SER"
    end

    st.chains.map(&.id).should eq ['A']
  end

  it "creates a residue automatically" do
    st = Chem::Structure.build do
      atom "CA", vec3(0, 0, 0)
    end

    st.chains.map(&.id).should eq ['A']
    st.residues.map(&.number).should eq [1]
    st.residues.map(&.name).should eq ["UNK"]
  end

  it "adds dummy atoms" do
    st = Chem::Structure.build do
      %w(N CA C O CB).each { |name| atom name, vec3(0, 0, 0) }
    end

    st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    st.atoms.all?(&.pos.zero?).should be_true
  end

  it "adds dummy atoms with coordinates" do
    st = Chem::Structure.build do
      atom vec3(1, 0, 0)
      atom vec3(2, 0, 0)
    end

    st.atoms.map(&.name).should eq ["C1", "C2"]
    st.atoms.map(&.x).should eq [1, 2]
  end

  it "adds atom with named arguments" do
    st = Chem::Structure.build do
      atom "OD1", vec3(0, 0, 0), partial_charge: -0.56, temperature_factor: 43.24
    end

    atom = st.atoms[-1]
    atom.partial_charge.should eq -0.56
    atom.temperature_factor.should eq 43.24
  end

  it "adds bonds by atom number" do
    structure = Chem::Structure.build do
      atom :O, vec3(0, 0, 0)
      atom :H, vec3(-1, 0, 0)
      atom :H, vec3(1, 0, 0)

      bond 1, 2
      bond 1, 3
    end

    expected = [{"O1", "H1"}, {"O1", "H2"}]
    structure.bonds.map(&.atoms.map(&.name)).should eq expected
  end

  it "sets secondary structure" do
    structure = Chem::Structure.build do
      chain { %w(PHE ARG ALA).each { |name| residue name } }
      chain { %w(ILE VAL).each { |name| residue name } }
      secondary_structure({'A', 1, nil}, {'A', 2, nil}, :right_handed_helix_alpha)
      secondary_structure({'B', 2, nil}, {'B', 2, nil}, :beta_strand)
    end

    structure.residues.map(&.sec.code).should eq ['H', 'H', '0', '0', 'E']
  end

  it "does not guess bond orders if hydrogens are missing" do
    structure = load_file("residue_type_unknown_covalent_ligand.pdb", guess_bonds: true)
    structure.formal_charge.should eq 0
    structure.atoms.count(&.formal_charge.zero?.!).should eq 0
    structure.bonds.size.should eq 59
    structure.bonds.count(&.single?.!).should eq 0
  end

  it "assigns bond orders for a structure without hydrogens" do
    structure = Chem::Structure.build(guess_bonds: true) do
      residue "ICN" do
        atom :i, vec3(3.149, 0, 0)
        atom :c, vec3(1.148, 0, 0)
        atom :n, vec3(0, 0, 0)
      end
    end
    structure.bonds.size.should eq 2
    structure.dig('A', 1, "I1").bonds[structure.dig('A', 1, "C1")].order.should eq 1
    structure.dig('A', 1, "C1").bonds[structure.dig('A', 1, "N1")].order.should eq 3
  end

  describe "#kekulize" do
    it_kekulizes "indole and benzene", "783.mol2", %w(
      C1=C2 C2-C3 C3=C4 C4-C5 C5=C6 C1-C6
      C4-N3 N3-C8 CN4=C8
      C1'=C2' C2'-C3' C3'=C4' C4'-C5' C5'=C6' C1'-C6'
      C1B-C2B C2B=C3B C3B-C4B C4B=C5B C5B-C6B C1B=C6B
    )

    it_kekulizes "quinazoline and pyrazole", "8FX.mol2", %w(
      C1=C2 C2-C3 C3=C4 C4-C20 C19-C20 C1-C19
      C18=C19 N7-C18 C17=N7 N6-C17 N6=C20
      C5-C6 C6=C7 C7-N2 N2-N3 C5=N3
    )

    it_kekulizes "napthalene", "naphthalene.mol2", %w(
      C1-C2 C2=C3 C3-C4 C4=C9 C9-C10 C1=C10
      C4-C5 C5=C6 C6-C7 C7=C8 C8-C9
    )

    it_kekulizes "three fused rings", "tac.mol2", %w(
      C4=C6 C4-C7 C7=C8 C8-C9 N1=C9
      C8-C10 C9-C11 C10=C12 C11=C13 C12-C13
    )

    it_kekulizes "four fused rings", "ac1.mol2", %w(
      C1=C2 C2-C4 C4-C6 C6-C7 C3=C7 C1-C3
      C2-C8 C8=C9 C5-C9
      C3-C10 C10=C14 C11-C14 C5=C11
      C4=C12 C12-C15 C15=C16 C13-C16 C6=C13
    )

    it_kekulizes "rings joined by a simple ring", "flu.mol2", %w(
      C1=C2 C2-C7 C7=C13 C11-C13 C6=C11 C1-C6
      C6-C12 C12=C14 C8-C14 C3=C8
      C4-C5 C5=C10 C10-C16 C15=C16 C9-C15 C4=C9
    )
  end
end

private def it_kekulizes(desc, path, bonds_spec, file = __FILE__, line = __LINE__)
  it "kelulizes #{desc}", file, line do
    structure = load_file(path)
    bonds = structure.bonds.map &.to_s
    bonds_spec.each do |bond|
      bonds.should contain bond
    end
  end
end
