require "../spec_helper"

describe Chem::SDF::Reader do
  it "parses a SDF file" do
    path = Path[spec_file("0B1.sdf")]
    structures = Array(Chem::Structure).from_sdf path
    structures.size.should eq 172
    structures.each do |structure|
      structure.source_file.should eq path.expand
      structure.cell?.should be_nil
      structure.atoms.size.should eq 47
      structure.bonds.size.should eq 50
      # SDF uses Mol behind the scenes so no need to do further checks

      structure.metadata.keys.should eq %w(cid energy)
      structure.metadata["cid"].raw.should be_a Int32
      structure.metadata["energy"].raw.should be_a Float64
    end

    structures[0].metadata["cid"].should eq 42
    structures[0].metadata["energy"].should eq -69.2498879662534

    structures[86].metadata["cid"].should eq 95
    structures[86].metadata["energy"].should eq -66.80468478035203
  end
end
