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

      res_t.atoms.size.should eq 18
      res_t.atoms.zip(residue.atoms) do |template, atom|
        atom.should match template # uses Atom#matches? internally
      end

      res_t.bonds.size.should eq 19
      res_t.bonds.zip(residue.bonds) do |template, bond|
        bond.should match template # uses Bond#matches? internally
      end
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueTemplate.build(&.name("O2").spec("O1=O2").root("O1"))
        .inspect.should eq "<ResidueTemplate O2>"
      Chem::ResidueTemplate.build(&.name("HOH").type(:solvent).spec("O"))
        .inspect.should eq "<ResidueTemplate HOH, solvent>"
      Chem::ResidueTemplate.build(&.name("GLY").code('G').type(:protein)
        .spec("N(-H)-CA(-C=O)"))
        .inspect.should eq "<ResidueTemplate GLY(G), protein>"
    end
  end
end
