require "./spec_helper"

describe Chem::ResidueTemplate do
  describe ".from_residue" do
    it "creates a template from a residue" do
      residue = load_file("naphthalene.mol2").residues[0]
      res_t = Chem::ResidueTemplate.from_residue residue
      res_t.name.should eq residue.name
      res_t.code.should eq residue.code
      res_t.type.should eq residue.type
      res_t.description.should be_nil
      res_t.root_atom.name.should eq residue.atoms[0].name
      res_t.aliases.should be_empty
      res_t.link_bond.should be_nil
      res_t.symmetric_atom_groups.should be_nil

      res_t.atoms.size.should eq residue.atoms.size
      res_t.atoms.zip(residue.atoms) do |template, atom|
        atom.should match template # uses Atom#matches? internally
      end

      res_t.bonds.size.should eq residue.bonds.size
      res_t.bonds.zip(residue.bonds) do |template, bond|
        bond.should match template # uses Bond#matches? internally
      end
    end

  describe "#[]" do
    it "raises if unknown atom" do
      expect_raises IndexError, "Unknown atom template \"CA\" in <ResidueTemplate ASD>" do
        Chem::ResidueTemplate.build(&.name("ASD").spec("CX"))["CA"]
      end
    end
  end

  describe "#[]?" do
    it "returns an atom template" do
      res_t = Chem::ResidueTemplate.build &.name("ASD").spec("CX")
      atom_t = res_t["CX"]?.should_not be_nil
      atom_t.name.should eq "CX"
    end

    it "returns nil if unknown atom" do
      Chem::ResidueTemplate.build(&.name("ASD").spec("CX"))["CA"]?.should be_nil
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      Chem::ResidueTemplate.build(&.name("O2").spec("O1=O2").root("O1"))
        .to_s.should eq "<ResidueTemplate O2>"
      Chem::ResidueTemplate.build(&.name("HOH").type(:solvent).spec("O"))
        .to_s.should eq "<ResidueTemplate HOH solvent>"
      Chem::ResidueTemplate.build(&.name("GLY").code('G').type(:protein)
        .spec("N(-H)-CA(-C=O)"))
        .to_s.should eq "<ResidueTemplate GLY(G) protein>"
    end
  end

  describe "#polymer?" do
    it "tells if residue template is a polymer" do
      res_t = Chem::ResidueTemplate.build &.name("X").spec("C1=C2").root("C1")
      res_t.polymer?.should be_false

      res_t = Chem::ResidueTemplate.build &.name("X").spec("C1=C2").root("C1")
        .link_adjacent_by("C2=C1")
      res_t.polymer?.should be_true
    end
  end
end
