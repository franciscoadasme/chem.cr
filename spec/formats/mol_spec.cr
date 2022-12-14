require "../spec_helper"

describe Chem::Mol::Reader do
  it "parses a Mol V2000 file" do
    path = Path[spec_file("702_v2000.mol")]
    structure = Chem::Structure.read path
    structure.source_file.should eq path.expand
    structure.title.should eq "702"
    structure.atoms.size.should eq 9
    structure.bonds.size.should eq 8
    structure.atoms.reject(&.formal_charge.zero?)
      .to_h { |atom| {atom.serial, atom.formal_charge} }
      .should eq({1 => -2, 4 => 1, 6 => -1})
    structure.bonds.reject(&.single?)
      .to_h { |bond| {bond.atoms.map(&.serial), bond.order.to_i} }
      .should eq({ {1, 2} => 2 })
    structure.atoms[2].mass.should eq 14
  end

  it "parses a Mol V3000 file" do
    path = Path[spec_file("702_v3000.mol")]
    structure = Chem::Structure.read path
    structure.source_file.should eq path.expand
    structure.title.should eq "702"
    structure.atoms.size.should eq 9
    structure.bonds.size.should eq 8
    structure.atoms.reject(&.formal_charge.zero?)
      .to_h { |atom| {atom.serial, atom.formal_charge} }
      .should eq({1 => -2, 4 => 1, 6 => -1})
    structure.bonds.reject(&.single?)
      .to_h { |bond| {bond.atoms.map(&.serial), bond.order.to_i} }
      .should eq({ {1, 2} => 2 })
    structure.atoms[2].mass.should eq 14
  rescue ex : Chem::ParseException
    puts ex.inspect_with_location
    raise ex
  end
end
