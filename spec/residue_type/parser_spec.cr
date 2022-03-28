require "../spec_helper"

describe Chem::ResidueType::Parser do
  it "parses aliases" do
    parser = Chem::ResidueType::Parser.new(
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
    parser = Chem::ResidueType::Parser.new <<-SPEC.gsub(/\s+/, "")
      C1%1(-O25-C26)=C2(-O27-C28)-C3=C4(-C5%2=C6-%1)-C9-C8
      (-C7(=O24)-%2)-C10-C11%3-C12-C13-N14(-C15-C16-%3)
      -C17-C18%4=C19-C20=C21-C22=C23-%4
    SPEC
    parser.parse
    parser.atom_types.size.should eq 28
    parser.bond_types.size.should eq 31
    parser.bond_types.count(&.double?).should eq 7
  end

  it "raises if a bond specifies the same atom" do
    expect_raises Chem::ParseException, "Atom O cannot be bonded to itself" do
      Chem::ResidueType::Parser.new("O%1=%1").parse
    end
  end

  it "raises when adding the same bond twice with different order" do
    expect_raises Chem::ParseException, "Bond CD2=CE2 already exists" do
      Chem::ResidueType::Parser.new("CD2%1=CE2-%1").parse
    end
  end

  it "parses an atom with explicit valency" do
    parser = Chem::ResidueType::Parser.new "CB-SG(1)"
    parser.parse
    parser.atom_types.size.should eq 2
    parser.bond_types.size.should eq 1
    parser.atom_types[1].valency.should eq 1
  end

  it "parses an atom with explicit valency followed by a bond" do
    parser = Chem::ResidueType::Parser.new "S(2)=O1"
    parser.parse
    parser.atom_types.size.should eq 2
    parser.bond_types.size.should eq 1
    parser.atom_types[0].valency.should eq 2
  end

  it "parses an atom with explicit element" do
    parser = Chem::ResidueType::Parser.new "CA[Ca]"
    parser.parse
    parser.atom_types.size.should eq 1
    parser.bond_types.size.should eq 0
    parser.atom_types[0].element.should eq Chem::PeriodicTable::Ca
  end

  it "parses labels" do
    spec = "CB-CG%1=CD1-NE1-CE2(=CD2%2#%1)-CZ2=CH2-CZ3=CE3=%2"
    parser = Chem::ResidueType::Parser.new spec
    parser.parse
    parser.atom_types.size.should eq 10
    parser.bond_types.size.should eq 11

    bond_type = parser.bond_types.find { |b| b[0].name == "CG" && b[1].name == "CD2" }
    bond_type = bond_type.should_not be_nil
    bond_type.order.should eq 3

    bond_type = parser.bond_types.find { |b| b[0].name == "CD2" && b[1].name == "CE3" }
    bond_type = bond_type.should_not be_nil
    bond_type.order.should eq 2
  end

  it "raises if label is before an atom" do
    expect_raises(Chem::ParseException, "Label %1 must be preceded by an atom") do
      Chem::ResidueType::Parser.new("%1CB").parse
    end
  end

  it "raises if label is unknown" do
    expect_raises(Chem::ParseException, "Unknown label %1") do
      Chem::ResidueType::Parser.new("CB-CG-CD-%1").parse
    end
  end

  it "raises if label is duplicate" do
    expect_raises(Chem::ParseException, "Duplicate label %1") do
      Chem::ResidueType::Parser.new("CB%1-CG-CD%1").parse
    end
  end

  it "raises if unused label" do
    expect_raises(Chem::ParseException, "Unclosed label %1") do
      Chem::ResidueType::Parser.new("CB%1-CG-CD").parse
    end
  end

  it "raises if atom type is duplicate" do
    expect_raises(Chem::ParseException, "Duplicate atom type CB") do
      Chem::ResidueType::Parser.new("CB-CG-CD-CB").parse
    end
  end
end
