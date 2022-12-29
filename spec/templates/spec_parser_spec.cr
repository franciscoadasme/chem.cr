require "../spec_helper"

describe Chem::Templates::SpecParser do
  it "parses aliases" do
    parser = Chem::Templates::SpecParser.new(
      "%{foo}-CB-%{bar}-CD2=%{baz}",
      aliases: {
        "foo" => "C-CA",
        "bar" => "CG(=CD1)",
        "baz" => "OZ",
      }
    )
    parser.parse
    parser.atoms.size.should eq 7
    parser.bonds.size.should eq 6
    parser.atoms.map(&.name).should eq [
      "C", "CA", "CB", "CG", "CD1", "CD2", "OZ",
    ]
    parser.bonds.count(&.order.==(2)).should eq 2
  end

  it "parses a complex residue" do
    parser = Chem::Templates::SpecParser.new <<-SPEC.gsub(/\s+/, "")
      C1%1(-O25-C26)=C2(-O27-C28)-C3=C4(-C5%2=C6-%1)-C9-C8
      (-C7(=O24)-%2)-C10-C11%3-C12-C13-N14(-C15-C16-%3)
      -C17-C18%4=C19-C20=C21-C22=C23-%4
    SPEC
    parser.parse
    parser.atoms.size.should eq 28
    parser.bonds.size.should eq 31
    parser.bonds.count(&.order.==(2)).should eq 7
  end

  it "raises if a bond specifies the same atom" do
    expect_raises Chem::ParseException, "Atom O cannot be bonded to itself" do
      Chem::Templates::SpecParser.new("O%1=%1").parse
    end
  end

  it "raises when adding the same bond twice with different order" do
    expect_raises Chem::ParseException, "A bond between CD2 and CE2 already exists" do
      Chem::Templates::SpecParser.new("CD2%1=CE2-%1").parse
    end
  end

  it "raises if branch does not start with a bond" do
    expect_raises(
      Chem::ParseException,
      "Expected a bond at the beginning of a branch, got '1'"
    ) do
      Chem::Templates::SpecParser.new("CB-SG(1)").parse
    end
  end

  it "parses an atom with explicit element" do
    parser = Chem::Templates::SpecParser.new "[CA|Ca]"
    parser.parse
    parser.atoms.size.should eq 1
    parser.bonds.size.should eq 0
    parser.atoms[0].element.should eq Chem::PeriodicTable::Ca
  end

  it "parses labels" do
    spec = "CB-CG%1=CD1-NE1-CE2(=CD2%2#%1)-CZ2=CH2-CZ3=CE3=%2"
    parser = Chem::Templates::SpecParser.new spec
    parser.parse
    parser.atoms.size.should eq 10
    parser.bonds.size.should eq 11

    bond_t = parser.bonds.find { |b| b.lhs == "CG" && b.rhs == "CD2" }
    bond_t = bond_t.should_not be_nil
    bond_t.order.should eq 3

    bond_t = parser.bonds.find { |b| b.lhs == "CD2" && b.rhs == "CE3" }
    bond_t = bond_t.should_not be_nil
    bond_t.order.should eq 2
  end

  it "raises if label is before an atom" do
    expect_raises(Chem::ParseException, "Expected atom before label %1") do
      Chem::Templates::SpecParser.new("%1CB").parse
    end
  end

  it "raises if label is unknown" do
    expect_raises(Chem::ParseException, "Unknown label %1") do
      Chem::Templates::SpecParser.new("CB-CG-CD-%1").parse
    end
  end

  it "raises if label is duplicate" do
    expect_raises(Chem::ParseException, "Duplicate label %1") do
      Chem::Templates::SpecParser.new("CB%1-CG-CD%1").parse
    end
  end

  it "raises if unused label" do
    expect_raises(Chem::ParseException, "Unclosed label %1") do
      Chem::Templates::SpecParser.new("CB%1-CG-CD").parse
    end
  end

  it "raises if atom is duplicate" do
    expect_raises(Chem::ParseException, "Duplicate atom CB") do
      Chem::Templates::SpecParser.new("CB-CG-CD-CB").parse
    end
  end

  it "parses an atom with negative charge" do
    parser = Chem::Templates::SpecParser.new("[CB-]-CG")
    parser.parse
    parser.atoms.size.should eq 2
    parser.bonds.size.should eq 1
    parser.atoms.map(&.formal_charge).should eq [-1, 0]
  end

  it "raises if bond is at the end" do
    expect_raises(Chem::ParseException, "Unmatched bond") do
      Chem::Templates::SpecParser.new("CB-CG=").parse
    end
  end

  it "raises if bond is at the end of a branch" do
    expect_raises(Chem::ParseException, "Unmatched bond") do
      Chem::Templates::SpecParser.new("CB-CG(-CD1-)").parse
    end
  end

  it "raises if two contiguous bonds" do
    expect_raises(Chem::ParseException, "Unmatched bond") do
      Chem::Templates::SpecParser.new("CB-CG-=CD").parse
    end
    expect_raises(Chem::ParseException, "Unmatched bond") do
      Chem::Templates::SpecParser.new("CB-CG--").parse
    end
  end

  it "raises if a bond is followed by a branch" do
    expect_raises(Chem::ParseException, "Branching bond must be inside the branch") do
      Chem::Templates::SpecParser.new("CB-CG-(-CD1)").parse
    end
  end

  it "parses negative charge at the end of branch" do
    parser = Chem::Templates::SpecParser.new "S(=O1)(=O2)(-[O3-])(-[O4-])"
    parser.parse
    parser.atoms.size.should eq 5
    parser.bonds.size.should eq 4
    parser.atoms.map(&.formal_charge).should eq [0, 0, 0, -1, -1]
  end

  it "parses implicit bonds" do
    parser = Chem::Templates::SpecParser.new "O1=SG{=S}(-[O3-]){-C}"
    parser.parse
    parser.atoms.size.should eq 3
    parser.bonds.size.should eq 2
    parser.implicit_bonds.size.should eq 2
    parser.implicit_bonds.map { |bond| {bond.lhs, bond.order.to_i} }.should eq [
      {"SG", 2}, {"SG", 1},
    ]
    parser.atoms.map(&.formal_charge).should eq [0, 0, -1]
  end

  it "raises if an implicit bond is after a bond" do
    expect_raises(
      Chem::ParseException,
      "Branching bond must be inside the implicit branch"
    ) do
      Chem::Templates::SpecParser.new("CB-SG-{-C}-CD").parse
    end
  end

  it "raises if implicit branch is not started with a bond" do
    expect_raises(
      Chem::ParseException,
      "Expected bond at the beginning of an implicit branch, got 'C'"
    ) do
      Chem::Templates::SpecParser.new("CB-SG{C}-CD").parse
    end
  end

  it "raises if two atoms are contiguous" do
    expect_raises(Chem::ParseException, "Expected bond between atoms") do
      Chem::Templates::SpecParser.new("C1C2").parse
    end
  end

  it "parses explicit hydrogens" do
    parser = Chem::Templates::SpecParser.new "[NH4+]"
    parser.parse
    parser.atoms.size.should eq 1
    parser.bonds.size.should eq 0
    parser.atoms[0].name.should eq "N"
    parser.atoms[0].explicit_hydrogens.should eq 4
    parser.atoms[0].formal_charge.should eq 1
  end

  it "raises on numeric atom name" do
    expect_raises(Chem::ParseException, "Expected atom name") do
      Chem::Templates::SpecParser.new("[12H2+]").parse
    end
  end

  it "parses an atom name ending with H2 in brackets" do
    parser = Chem::Templates::SpecParser.new "[NH2H4+]"
    parser.parse
    parser.atoms.size.should eq 1
    parser.bonds.size.should eq 0
    parser.atoms[0].name.should eq "NH2"
    parser.atoms[0].explicit_hydrogens.should eq 4
    parser.atoms[0].formal_charge.should eq 1
  end

  it "parses consecutive charge signs" do
    parser = Chem::Templates::SpecParser.new "[TI++++]"
    parser.parse
    parser.atoms.size.should eq 1
    parser.bonds.size.should eq 0
    parser.atoms[0].name.should eq "TI"
    parser.atoms[0].explicit_hydrogens.should eq 0
    parser.atoms[0].formal_charge.should eq 4
  end
end
