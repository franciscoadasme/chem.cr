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

      other.n_chains.should eq 1
      other.n_residues.should eq 46
      other.n_atoms.should eq 327
      other.bonds.size.should eq 337
      other.chains.map(&.id).should eq ['A']
      other.dig('A', 32).name.should eq "CYS"
      other.dig('A', 32).sec.beta_strand?.should be_true
      other.dig('A', 32, "CA").coords.should eq [8.140, 11.694, 9.635]

      other.cell.should eq structure.cell
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
