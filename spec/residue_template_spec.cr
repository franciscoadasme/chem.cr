require "./spec_helper"

describe Chem::ResidueTemplate do
  Chem::ResidueTemplate.register do
    name "LFG"
    spec "[N1H3+]-C2-C3-O4-C5(-C6)=O7"
    root "C5"
  end

  describe ".fetch" do
    it "returns a residue template by name" do
      residue_t = Chem::ResidueTemplate.fetch("LFG")
      residue_t.should be_a Chem::ResidueTemplate
      residue_t.name.should eq "LFG"
    end

    it "raises if residue template does not exist" do
      expect_raises Chem::Error, "Unknown residue template ASD" do
        Chem::ResidueTemplate.fetch("ASD")
      end
    end

    it "returns block's return value if residue template does not exist" do
      Chem::ResidueTemplate.fetch("ASD") { nil }.should be_nil
    end
  end

  describe ".register" do
    it "creates a residue template with multiple names" do
      Chem::ResidueTemplate.register do
        name "LXE", "EGR"
        spec "C1"
      end
      Chem::ResidueTemplate.fetch("LXE").should be Chem::ResidueTemplate.fetch("EGR")
    end

    it "fails when the residue name already exists" do
      expect_raises Chem::Error, "LXE residue template already exists" do
        Chem::ResidueTemplate.register do
          name "LXE"
          spec "C1"
          root "C1"
        end
      end
    end
  end

  describe "#inspect" do
    it "returns a string representation" do
      Chem::ResidueTemplate.build do
        name "O2"
        spec "O1=O2"
        root "O1"
      end.inspect.should eq "<ResidueTemplate O2>"

      Chem::ResidueTemplate.build do
        name "HOH"
        type :solvent
        spec "O"
      end.inspect.should eq "<ResidueTemplate HOH, solvent>"

      Chem::ResidueTemplate.build do
        name "GLY"
        code 'G'
        type :protein
        spec "N(-H)-CA(-C=O)"
      end.inspect.should eq "<ResidueTemplate GLY(G), protein>"
    end
  end

  describe ".parse" do
    it "returns residue templates from YAML content" do
      templates = Chem::ResidueTemplate.parse <<-YAML
        templates:
          - description: Phenylalanine
            names: [PHE, PHY]
            code: F
            type: protein
            link_bond: C-N
            root: CA
            spec: "{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1"
            symmetry:
              - [[CD1, CD2], [CE1, CE2]]
        aliases:
          backbone: N(-H)-CA(-HA)(-C=O)
        YAML
      templates.size.should eq 1
      res_t = templates[0]?.should_not be_nil
      res_t.name.should eq "PHE"
      res_t.aliases.should eq %w(PHY)
      res_t.type.protein?.should be_true
      res_t.link_bond.to_s.should eq "C-N"
      res_t.description.should eq "Phenylalanine"
      res_t.root_atom.name.should eq "CA"
      res_t.code.should eq 'F'
      res_t.symmetric_atom_groups.should eq [[{"CD1", "CD2"}, {"CE1", "CE2"}]]
      res_t.atoms.size.should eq Chem::ResidueTemplate.fetch("PHE").atom_count
      res_t.bonds.size.should eq Chem::ResidueTemplate.fetch("PHE").bonds.size
    end
  end
end
