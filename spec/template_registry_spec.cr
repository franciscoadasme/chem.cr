require "./spec_helper"

describe Chem::TemplateRegistry do
  describe "#[]" do
    it "raises if residue template does not exist" do
      expect_raises Chem::Error, "Unknown residue template ASD" do
        Chem::TemplateRegistry.new["ASD"]
      end
    end
  end

  describe "#[]?" do
    it "returns a residue template by name" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
        templates:
          - names: [CX1, CX2]
            spec: CX
        YAML
      res_t = registry["CX1"]?.should_not be_nil
      res_t.should be_a Chem::ResidueTemplate
      res_t.name.should eq "CX1"
      registry["CX2"].should eq res_t
    end

    it "returns nil if residue template does not exist" do
      Chem::TemplateRegistry.new["ASD"]?.should be_nil
    end
  end

  describe "#<<" do
    it "adds a residue template" do
      res_t = Chem::ResidueTemplate.build do |builder|
        builder.name "ASD"
        builder.spec "CA"
      end
      registry = Chem::TemplateRegistry.new << res_t
      registry.size.should eq 1
      registry["ASD"].should eq res_t
    end

    it "adds a residue template with multiple names" do
      res_t = Chem::ResidueTemplate.build do |builder|
        builder.names "ASD", "DSA"
        builder.spec "CA"
      end
      registry = Chem::TemplateRegistry.new << res_t
      registry.size.should eq 1
      registry["ASD"].should eq registry["DSA"]
    end

    it "raises when the residue name already exists" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
        templates:
          - name: LXE
            spec: CX
        YAML
      expect_raises Chem::Error, "LXE residue template already exists" do
        registry.register do
          name "LXE"
          spec "C1"
        end
      end
    end
  end

  describe "#includes?" do
    it "tells if registry includes a residue template" do
      res_t1 = Chem::ResidueTemplate.build do |builder|
        builder.names "ASD", "DSA"
        builder.spec "CA"
      end
      res_t2 = Chem::ResidueTemplate.build do |builder|
        builder.name "CUX"
        builder.spec "CU"
      end
      res_t3 = Chem::ResidueTemplate.build do |builder|
        builder.name "ASD"
        builder.spec "CB"
      end
      registry = Chem::TemplateRegistry.new << res_t1
      registry.includes?(res_t1).should be_true
      registry.includes?(res_t2).should be_false
      registry.includes?(res_t3).should be_false # same name but different spec
    end
  end

  describe "#parse" do
    it "parses residue templates from YAML content" do
      content = <<-YAML
        templates:
          - description: Phenylalanine
            names: [PHE, PHY]
            code: F
            type: protein
            link_bond: C-N
            root: CA
            spec: '{backbone}-CB-CG%1=CD1-CE1=CZ-CE2=CD2-%1'
            symmetry:
              - [[CD1, CD2], [CE1, CE2]]
        aliases:
          backbone: N(-H)-CA(-HA)(-C=O)
        YAML
      templates = Chem::TemplateRegistry.new.parse(content).to_a
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
      res_t.atoms.size.should eq 20
      res_t.bonds.size.should eq 20
    end

    pending "parses top-level templates" do
    it "parses root" do
      registry = Chem::TemplateRegistry.new.parse <<-YAML
        templates:
          - name: LFG
            spec: 'O1=O2'
            root: O2
        YAML
      res_t = registry["LFG"].should_not be_nil
      res_t.root_atom.name.should eq "O2"
    end

      registry = Chem::TemplateRegistry.new.parse <<-YAML
        templates:
          - name: LFG
            spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
            root: C5
        YAML
      registry.size.should eq 1
    end
  end

  describe "#register" do
    it "creates a residue template with multiple names" do
      registry = Chem::TemplateRegistry.new
      registry.register do
        name "LXE", "EGR"
        spec "C1"
      end
      registry.size.should eq 1
      registry["LXE"].should eq registry["EGR"]
    end
  end

  describe "#reject" do
    it "returns a new registry with selected templates" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
        templates:
          - name: DDA
            spec: CA
          - name: DDB
            spec: CB
          - name: DDO
            spec: OXT
        YAML
      registry.reject(&.atoms[0].element.carbon?).to_a.map(&.name).should eq %w(DDO)
    end
  end

  describe "#select" do
    it "returns a new registry with selected templates" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
        templates:
          - name: DDA
            spec: CA
          - name: DDB
            spec: CB
          - name: DDO
            spec: OXT
        YAML
      registry.select(&.atoms[0].element.carbon?).to_a.map(&.name).should eq %w(DDA DDB)
    end
  end

  describe "#size" do
    it "returns the number of templates" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
      templates:
        - names: [DDA, DXA]
          spec: CA
        - name: DDB
          spec: CB
        - names: [DDO, DXO]
          spec: OXT
      YAML
      registry.size.should eq 3
    end
  end

  describe "#to_a" do
    it "returns the number of templates" do
      registry = Chem::TemplateRegistry.from_yaml <<-YAML
      templates:
        - names: [DDA, DXA]
          spec: CA
        - name: DDB
          spec: CB
        - names: [DDO, DXO]
          spec: OXT
      YAML
      registry.to_a.map(&.name).should eq %w(DDA DDB DDO)
    end
  end
end
