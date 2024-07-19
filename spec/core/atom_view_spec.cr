require "../spec_helper"

describe Chem::AtomView do
  # TODO: remove this global
  atoms = fake_structure.atoms

  describe "#[]" do
    it "gets atom by zero-based index" do
      atoms[4].name.should eq "CB"
    end

    it "gets atom by serial number" do
      atoms[serial: 5].name.should eq "CB"
    end
  end

  describe "#chains" do
    it "returns the chains" do
      atoms.chains.map(&.id).should eq ['A', 'B']
    end
  end

  describe "#fragments" do
    it "returns the fragments (1)" do
      struc = Chem::Structure.read spec_file("5e61--unwrapped.poscar")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (2)" do
      struc = Chem::Structure.read spec_file("5e61--unwrapped.poscar")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (3)" do
      struc = Chem::Structure.read spec_file("k2p_pore_b.xyz")
      struc.guess_bonds
      struc.atoms.fragments.map(&.size).sort!.should eq [1, 1, 1, 1, 304, 334]
    end

    it "returns fragments limited to the selected atoms " do
      struc = Chem::Structure.read spec_file("5e5v.pdb")
      struc.guess_bonds
      struc.atoms[0..205].fragments.map(&.size).should eq [103, 103]
      struc.atoms[0..150].fragments.map(&.size).should eq [103, 48]
      struc.atoms[0..50].fragments.map(&.size).should eq [51]
      struc.atoms[0..0].fragments.map(&.size).should eq [1]

      ary = struc.atoms[0..10].to_a
      ary.concat struc.atoms[150..158] # => O=C(i)-N(i+1)-H-CA, sidechain(i) (no CA(i)-CB)
      ary.concat struc.atoms[210..220] # => H1, H2, HOH, HOH, HOH
      Chem::AtomView.new(ary).fragments.map(&.size).should eq [11, 5, 4, 1, 1, 3, 3, 3]
    end
  end

  describe "#residues" do
    it "return the residues" do
      residues = atoms.residues
      residues.map(&.name).should eq %w(ASP PHE SER)
      residues.map(&.number).should eq [1, 2, 1]
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      atoms.size.should eq 25
    end
  end
end
