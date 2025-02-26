require "../spec_helper"

describe Chem::Maestro do
  it "parses a Maestro file" do
    structure = Chem::Structure.read spec_file("plain.mae")
    structure.chains.size.should eq 1
    structure.residues.size.should eq 1
    structure.atoms.size.should eq 5
  rescue ex : Chem::ParseException
    puts ex.inspect_with_location
    raise ex
  end
end
