require "../spec_helper"

describe Chem::Structure do
  describe ".build" do
    it "builds a structure" do
      st = Chem::Structure.build do
        title "Alanine"
        residue "ALA" do
          %w(N CA C O CB).each { |name| atom name, Vector.origin }
        end
      end

      st.title.should eq "Alanine"
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
    end
  end

  describe "#clone" do
    it "returns a copy of the structure" do
      structure = load_file "1crn.pdb"
      other = structure.clone

      other.should_not be structure
      other.dig('A').should_not be structure.dig('A')
      other.dig('A', 32).should_not be structure.dig('A', 32)
      other.dig('A', 13, "CA").should_not be structure.dig('A', 13, "CA")

      other.n_chains.should eq 1
      other.n_residues.should eq 46
      other.n_atoms.should eq 327
      other.bonds.size.should eq 337
      other.chains.map(&.id).should eq ['A']
      other.dig('A', 32).name.should eq "CYS"
      other.dig('A', 32).sec.beta_strand?.should be_true
      other.dig('A', 32, "CA").coords.should eq V[8.140, 11.694, 9.635]

      other.lattice.should eq structure.lattice
      other.experiment.should eq structure.experiment
      other.title.should eq structure.title
    end
  end

  describe "#delete" do
    it "deletes a chain" do
      structure = Structure.build do
        3.times { chain { } }
      end
      structure.n_chains.should eq 3
      structure.chains.map(&.id).should eq "ABC".chars

      structure.delete structure.chains[1]
      structure.n_chains.should eq 2
      structure.chains.map(&.id).should eq "AC".chars
      structure.dig?('B').should be_nil
    end

    it "does not delete another chain with the same id from the internal table (#86)" do
      structure = Structure.new
      Chain.new 'A', structure
      Chain.new 'B', structure
      Chain.new 'A', structure

      structure.n_chains.should eq 3
      structure.chains.map(&.id).should eq "ABA".chars

      structure.delete structure.chains[0]

      structure.n_chains.should eq 2
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

  describe "#periodic?" do
    it "returns true when a structure has a lattice" do
      structure = Structure.new
      structure.lattice = Lattice.new S[10, 20, 30]
      structure.periodic?.should be_true
    end

    it "returns false when a structure does not have a lattice" do
      Chem::Structure.new.periodic?.should be_false
    end
  end

  describe "#renumber_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file "5e5v--unwrapped.poscar", guess_topology: true
      structure.renumber_by_connectivity split_chains: false

      chains = structure.chains
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
      structure = load_file "hlx_gly.poscar"

      structure.each_residue.cons(2, reuse: true).each do |(a, b)|
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
        structure = load_file(filename, guess_topology: true)
        structure.renumber_by_connectivity
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
      structure = load_file "cylindrin--size-09.pdb"
      structure.renumber_by_connectivity split_chains: false
      structure.chains.map(&.id).should eq "ABC".chars
      structure.chains.map(&.n_residues).should eq [18] * 3
      structure.chains.map(&.residues.map(&.number)).should eq [(1..18).to_a] * 3
      structure.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 3
    end

    it "splits chains (#85)" do
      structure = load_file "cylindrin--size-09.pdb"
      structure.renumber_by_connectivity split_chains: true
      structure.chains.map(&.id).should eq "ABCDEF".chars
      structure.chains.map(&.n_residues).should eq [9] * 6
      structure.chains.map(&.residues.map(&.number)).should eq [(1..9).to_a] * 6
      structure.chains.map(&.residues.map(&.name)).should eq [
        %w(LEU LYS VAL LEU GLY ASP VAL ILE GLU),
      ] * 6
    end
  end

  describe "#write" do
    structure = Structure.build do
      title "ICN"
      lattice 5, 10, 10
      atom :I, V[-2, 0, 0]
      atom :C, V[0, 0, 0]
      atom :N, V[1.5, 0, 0]
    end

    it "writes a structure into a file" do
      path = File.tempname ".xyz"
      structure.write path
      File.read(path).should eq <<-EOS
        3
        ICN
        I         -2.00000        0.00000        0.00000
        C          0.00000        0.00000        0.00000
        N          1.50000        0.00000        0.00000\n
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
        I         -2.00000        0.00000        0.00000
        C          0.00000        0.00000        0.00000
        N          1.50000        0.00000        0.00000\n
        EOS
      File.delete path
    end

    it "writes a structure into an IO" do
      io = IO::Memory.new
      structure.write io, :xyz
      io.to_s.should eq <<-EOS
        3
        ICN
        I         -2.00000        0.00000        0.00000
        C          0.00000        0.00000        0.00000
        N          1.50000        0.00000        0.00000\n
        EOS
    end

    it "accepts file format as string" do
      io = IO::Memory.new
      structure.write io, "xyz"
      io.to_s.should eq <<-EOS
        3
        ICN
        I         -2.00000        0.00000        0.00000
        C          0.00000        0.00000        0.00000
        N          1.50000        0.00000        0.00000\n
        EOS
    end

    it "raises on invalid file format" do
      expect_raises ArgumentError do
        structure.write IO::Memory.new, "asd"
      end
    end
  end
end
