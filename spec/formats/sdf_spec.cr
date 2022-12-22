require "../spec_helper"

describe Chem::SDF::Reader do
  it "parses a SDF file" do
    path = Path[spec_file("0B1.sdf")]
    structures = Array(Chem::Structure).from_sdf path
    structures.size.should eq 172
    structures.each do |structure|
      structure.source_file.should eq path.expand
      structure.cell.should be_nil
      structure.atoms.size.should eq 47
      structure.bonds.size.should eq 50
      # SDF uses Mol behind the scenes so no need to do further checks
    end
  end
end
