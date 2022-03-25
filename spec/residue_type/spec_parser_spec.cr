require "../spec_helper"

describe Chem::ResidueType::SpecificationParser do
  it "parses aliases" do
    parser = Chem::ResidueType::SpecificationParser.new(
      "{foo}-CB-{bar}-CD2={baz}",
      aliases: {
        "foo" => "C-CA",
        "bar" => "CG(=CD1)",
        "baz" => "OZ",
      }
    )
    parser.parse
    parser.atom_types.size.should eq 7
    parser.bond_types.size.should eq 6
    parser.atom_types.map(&.name).should eq [
      "C", "CA", "CB", "CG", "CD1", "CD2", "OZ",
    ]
    parser.bond_types.count(&.double?).should eq 2
  end

  it "parses a complex residue" do
    parser = Chem::ResidueType::SpecificationParser.new <<-SPEC.gsub(/\s+/, "")
      C1(-O25-C26)=C2(-O27-C28)-C3=C4(-C5=C6-C1)-C9-C8
      (-C7(=O24)-C5)-C10-C11-C12-C13-N14(-C15-C16-C11)
      -C17-C18=C19-C20=C21-C22=C23-C18
    SPEC
    parser.parse
    parser.atom_types.size.should eq 28
    parser.bond_types.size.should eq 31
    parser.bond_types.count(&.double?).should eq 7
  end

  it "raises if a bond specifies the same atom" do
    expect_raises Chem::Error, "Atom O cannot be bonded to itself" do
      Chem::ResidueType::SpecificationParser.new("O=O").parse
    end
  end

  it "raises when adding the same bond twice with different order" do
    expect_raises Chem::ParseException, "Bond CD2=CE2 already exists" do
      Chem::ResidueType::SpecificationParser.new("CD2=CE2-CD2").parse
    end
  end

  it "parses an atom with explicit valency" do
    parser = Chem::ResidueType::SpecificationParser.new "CB-SG(1)"
    parser.parse
    parser.atom_types.size.should eq 2
    parser.bond_types.size.should eq 1
    parser.atom_types[1].valency.should eq 1
  end

  it "parses an atom with explicit valency followed by a bond" do
    parser = Chem::ResidueType::SpecificationParser.new "S(2)=O1"
    parser.parse
    parser.atom_types.size.should eq 2
    parser.bond_types.size.should eq 1
    parser.atom_types[0].valency.should eq 2
  end

  it "parses an atom with explicit element" do
    parser = Chem::ResidueType::SpecificationParser.new "CA[Ca]"
    parser.parse
    parser.atom_types.size.should eq 1
    parser.bond_types.size.should eq 0
    parser.atom_types[0].element.should eq Chem::PeriodicTable::Ca
  end
end
