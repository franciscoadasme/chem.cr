require "./spec_helper"

describe Chem::AtomCollection do
  system = fake_system

  describe "#atoms" do
    it "returns an atom view" do
      system.atoms.should be_a Chem::AtomView
    end
  end

  describe "#each_atom" do
    it "iterates over each atom when called with block" do
      ary = [] of Int32
      system.each_atom { |atom| ary << atom.serial }
      ary.should eq (1..26).to_a
    end

    it "returns an iterator when called without block" do
      system.each_atom.should be_a Iterator(Chem::Atom)
    end
  end
end

describe Chem::AtomView do
  atoms = fake_system.atoms

  describe "#[]" do
    it "gets atom by zero-based index" do
      atoms[4].name.should eq "CB"
    end

    it "gets atom by serial number" do
      atoms[serial: 5].name.should eq "CB"
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      atoms.size.should eq 26
    end
  end
end

describe Chem::ChainCollection do
  system = fake_system

  describe "#chains" do
    it "returns a chain view" do
      system.chains.should be_a Chem::ChainView
    end
  end

  describe "#each_chain" do
    it "iterates over each chain when called with block" do
      ary = [] of Char?
      system.each_chain { |chain| ary << chain.id }
      ary.should eq ['A', 'B']
    end

    it "returns an iterator when called without block" do
      system.each_chain.should be_a Iterator(Chem::Chain)
    end
  end
end

describe Chem::ChainView do
  chains = fake_system.chains

  describe "#[]" do
    it "gets chain by zero-based index" do
      chains[0].id.should eq 'A'
    end

    it "gets chain by identifier" do
      chains['A'].id.should eq 'A'
    end
  end

  describe "#size" do
    it "returns the number of chains" do
      chains.size.should eq 2
    end
  end
end

describe Chem::ResidueCollection do
  system = fake_system

  describe "#each_residue" do
    it "iterates over each residue when called with block" do
      ary = [] of String
      system.each_residue { |residue| ary << residue.name }
      ary.should eq ["GLU", "PHE", "SER"]
    end

    it "returns an iterator when called without block" do
      system.each_residue.should be_a Iterator(Chem::Residue)
    end
  end

  describe "#residues" do
    it "returns a residue view" do
      system.residues.should be_a Chem::ResidueView
    end
  end
end

describe Chem::ResidueView do
  residues = fake_system.residues

  describe "#[]" do
    it "gets residue by zero-based index" do
      residues[1].name.should eq "PHE"
    end

    it "gets residue by serial number" do
      residues[serial: 2].name.should eq "PHE"
    end
  end

  describe "#size" do
    it "returns the number of residues" do
      residues.size.should eq 3
    end
  end
end

describe Chem::System do
  system = fake_system

  describe "#size" do
    it "returns the number of atoms" do
      system.size.should eq 26
    end
  end
end
