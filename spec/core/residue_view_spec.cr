require "../spec_helper"

describe Chem::ResidueView do
  residues = load_file("insertion_codes.pdb").residues

  describe "#[]" do
    it "gets residue by zero-based index" do
      residues[1].name.should eq "GLY"
    end

    it "gets residue by serial number" do
      residues[serial: 76].name.should eq "VAL"
    end

    it "gets residue by serial number (insertion codes)" do
      residue = residues[serial: 75]
      residue.number.should eq 75
      residue.insertion_code.should eq nil
      residue.name.should eq "TRP"
    end

    it "gets residue by serial number and insertion code" do
      residues = load_file("insertion_codes.pdb").residues
      residue = residues[75, 'B']
      residue.number.should eq 75
      residue.insertion_code.should eq 'B'
      residue.name.should eq "SER"
    end
  end

  describe "#size" do
    it "returns the number of residues" do
      residues.size.should eq 7
    end
  end
end
