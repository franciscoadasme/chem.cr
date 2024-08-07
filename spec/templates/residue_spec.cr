require "../spec_helper"

describe Chem::Templates::Residue do
  describe ".new" do
    it "raises if duplicate names" do
      expect_raises Chem::Error,
        %q(Duplicate atom name "X" found in <Templates::Residue VYX>) do
        Chem::Templates::Residue.new ["VYX"],
          code: nil,
          type: :other,
          description: nil,
          atoms: [Chem::Templates::Atom.new("X", "C"), Chem::Templates::Atom.new("X", "O")],
          bonds: [] of Chem::Templates::Bond,
          root: "X"
      end
    end

    it "creates a template from a residue" do
      residue = load_file("naphthalene.mol2").residues[0]
      res_t = Chem::Templates::Residue.build residue
      res_t.names.should eq [residue.name]
      res_t.code.should eq residue.code
      res_t.type.should eq residue.type
      res_t.description.should be_nil
      res_t.root.name.should eq "C4"
      res_t.link_bond.should be_nil
      res_t.symmetric_atom_groups.should be_nil

      res_t.atoms.size.should eq residue.atoms.size
      res_t.atoms.zip(residue.atoms) do |template, atom|
        atom.should match template # uses Atom#matches? internally
      end

      res_t.bonds.size.should eq residue.atoms.bonds.size
      res_t.bonds.zip(residue.atoms.bonds) do |template, bond|
        bond.should match template # uses Bond#matches? internally
      end
    end

    it "guesses link bond from connectivity" do
      residue = load_file("hlx_phe--theta-90.000--c-26.10.pdb").residues[0]
      residue.name = "UNK" # force link bond guessing (no template)
      res_t = Chem::Templates::Residue.build residue
      link_bond = res_t.link_bond.should_not be_nil
      link_bond.should eq Chem::Templates::Bond.new(res_t["C"], res_t["N"])
      link_bond.atoms.map(&.name).to_a.should eq %w(C N) # ensure order
    end

    it "does not find a link bond for an isolated molecule" do
      residue = load_file("benzene.mol2").residues[0]
      res_t = Chem::Templates::Residue.build residue
      res_t.link_bond.should be_nil
    end

    it "raises if missing connectivity" do
      structure = Chem::Structure.build do |builder|
        builder.atom vec3(0, 0, 0)
      end
      expect_raises(Chem::Error,
        "Cannot create template from <Residue A:UNK1> due to missing connectivity") do
        Chem::Templates::Residue.build structure.residues[0]
      end
    end

    it "raises if duplicate names" do
      structure = Chem::Structure.build do |builder|
        builder.residue "GHY"
        builder.atom "CX1", vec3(1, 0, 5)
        builder.atom "CX1", vec3(26, 3, 1)
      end
      expect_raises Chem::Error,
        %q(Duplicate atom name "CX1" found in <Residue A:GHY1>) do
        Chem::Templates::Residue.build structure.residues[0]
      end
    end

    it "guesses root to be the most complex atom" do
      structure = Chem::Structure.from_mol2 "spec/data/mol2/dmpe.mol2"
      res_t = Chem::Templates::Residue.build structure.residues[0]
      res_t.root.name.should eq "P"
    end
  end

  describe "#[]" do
    it "raises if unknown atom" do
      expect_raises(KeyError,
        "Atom \"CA\" not found in <Templates::Residue ASD>") do
        Chem::Templates::Residue.build(&.name("ASD").spec("CX"))["CA"]
      end
    end

    it "raises if unknown bond" do
      res_t = Chem::Templates::Residue.build &.name("ASD").spec("CA=CB")
      expect_raises(KeyError,
        "Bond between \"CA\" and \"CX\" not found in <Templates::Residue ASD>") do
        res_t["CA", "CX"]
      end
    end
  end

  describe "#[]?" do
    it "returns an atom template" do
      res_t = Chem::Templates::Residue.build &.name("ASD").spec("CX")
      atom_t = res_t["CX"]?.should_not be_nil
      atom_t.name.should eq "CX"
    end

    it "returns nil if unknown atom" do
      Chem::Templates::Residue.build(&.name("ASD").spec("CX"))["CA"]?.should be_nil
    end

    it "returns a bond template" do
      res_t = Chem::Templates::Residue.build &.name("ASD").spec("CA=CB")
      bond_t = res_t.bonds.find! { |bond_t| "CA".in?(bond_t) && "CB".in?(bond_t) }
      res_t[res_t["CA"], res_t["CB"]]?.should eq bond_t # using atom templates
      res_t["CA", "CB"]?.should eq bond_t               # using atom names
    end

    it "returns nil if unknown atom" do
      res_t = Chem::Templates::Residue.build &.name("ASD").spec("CA=CB")
      res_t["CA", "CX"]?.should be_nil
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      Chem::Templates::Residue.build(&.name("O2").spec("O1=O2"))
        .to_s.should eq "<Templates::Residue O2>"
      Chem::Templates::Residue.build(&.name("HOH").type(:solvent).spec("O"))
        .to_s.should eq "<Templates::Residue HOH solvent>"
      Chem::Templates::Residue.build(&.name("GLY").code('G').type(:protein)
        .spec("N(-H)-CA(-C=O)"))
        .to_s.should eq "<Templates::Residue GLY(G) protein>"
    end
  end

  describe "#polymer?" do
    it "tells if residue template is a polymer" do
      res_t = Chem::Templates::Residue.build &.name("X").spec("C1=C2")
      res_t.polymer?.should be_false

      res_t = Chem::Templates::Residue.build &.name("X").spec("C1=C2")
        .link_adjacent_by("C2=C1")
      res_t.polymer?.should be_true
    end
  end
end
