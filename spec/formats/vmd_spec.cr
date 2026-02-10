require "../spec_helper"

describe Chem::VMD do
  describe ".write" do
    it "writes a VMD command script" do
      struc = Chem::PDB.read spec_file("1crn.pdb")
      expected = File.read(spec_file("1crn.vmd"))
        .gsub("1crn.pdb", Path[spec_file("1crn.pdb")].expand)

      io = IO::Memory.new
      Chem::VMD.write(io, struc)
      io.to_s.should eq expected
    end
  end
end
