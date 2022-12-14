require "../spec_helper"

describe Chem::Mol::Reader do
  it "parses a Mol file" do
    structure = load_file "702.mol"
    structure.source_file.should eq Path[spec_file("702.mol")].expand
    structure.title.should eq "702"
    structure.atoms.size.should eq 9
    structure.bonds.size.should eq 8
    structure.atoms.map(&.formal_charge).should eq [
      -2, 0, 0, 1, 0, -1, 0, 0, 0,
    ]
    structure.atoms[2].mass.should eq 14
  rescue ex : Chem::ParseException
    puts ex.inspect_with_location
    raise ex
  end
end
