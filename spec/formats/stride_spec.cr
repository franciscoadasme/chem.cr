require "../spec_helper"

describe Chem::Protein::Stride do
  describe ".write" do
    it "writes in the STRIDE file format" do
      struc = Chem::PDB.read spec_file("1crn.pdb")
      expected = File.read spec_file("1crn.stride")

      io = IO::Memory.new
      Chem::Protein::Stride.write io, struc
      io.to_s.should eq expected
    end
  end
end
