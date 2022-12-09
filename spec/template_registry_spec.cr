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
      registry = Chem::TemplateRegistry.new
      registry.register &.names(%w(CX1 CX2)).spec("CX")
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
      res_t = Chem::ResidueTemplate.build &.name("ASD").spec("CA")
      registry = Chem::TemplateRegistry.new << res_t
      registry.size.should eq 1
      registry["ASD"].should eq res_t
    end

    it "adds a residue template with multiple names" do
      res_t = Chem::ResidueTemplate.build &.names(%w(ASD DSA)).spec("CA")
      registry = Chem::TemplateRegistry.new << res_t
      registry.size.should eq 1
      registry["ASD"].should eq registry["DSA"]
    end

    it "raises when the residue name already exists" do
      registry = Chem::TemplateRegistry.new
      registry.register &.name("LXE").spec("CX")
      expect_raises Chem::Error, "LXE residue template already exists" do
        registry << Chem::ResidueTemplate.build &.name("LXE").spec("C1")
      end
    end
  end

  describe "#alias" do
    it "registers an alias" do
      registry = Chem::TemplateRegistry.new
      registry.register &.name("HOH").spec("O")
      registry.alias "TIP3", to: "HOH"
      registry["HOH"].should eq registry["TIP3"]
    end

    it "raises if unknown template" do
      expect_raises Chem::Error, "Unknown residue template HOH" do
        Chem::TemplateRegistry.new.alias "TIP3", to: "HOH"
      end
    end
  end

  describe "#includes?" do
    it "tells if registry includes a residue template" do
      res_t1 = Chem::ResidueTemplate.build &.names(%w(ASD DSA)).spec("CA")
      res_t2 = Chem::ResidueTemplate.build &.name("CUX").spec("CU")
      res_t3 = Chem::ResidueTemplate.build &.name("ASD").spec("CB")
      registry = Chem::TemplateRegistry.new << res_t1
      registry.includes?(res_t1).should be_true
      registry.includes?(res_t2).should be_false
      registry.includes?(res_t3).should be_false # same name but different spec
    end
  end

  describe "#load" do
    it "loads a template from structure file" do
      registry = Chem::TemplateRegistry.new.load spec_file("benzene.mol2")
      registry["BEN"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(C1 C2 C3 C4 C5 C6)
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
          backbone: 'N(-H)-CA(-HA)(-C=O)'
        YAML
      templates = Chem::TemplateRegistry.new.parse(content).to_a
      templates.size.should eq 1
      res_t = templates[0]?.should_not be_nil
      res_t.name.should eq "PHE"
      res_t.aliases.should eq %w(PHY)
      res_t.type.protein?.should be_true
      res_t.link_bond.to_s.should eq "<BondTemplate C-N>"
      res_t.description.should eq "Phenylalanine"
      res_t.root.name.should eq "CA"
      res_t.code.should eq 'F'
      res_t.symmetric_atom_groups.should eq [[{"CD1", "CD2"}, {"CE1", "CE2"}]]
      res_t.atoms.size.should eq 20
      res_t.bonds.size.should eq 20
    end

    it "parses root" do
      registry = Chem::TemplateRegistry.new.parse <<-YAML
        - name: LFG
          spec: 'O1=O2'
          root: O2
        YAML
      res_t = registry["LFG"].should_not be_nil
      res_t.root.name.should eq "O2"
    end

    it "parses top-level templates" do
      registry = Chem::TemplateRegistry.new.parse <<-YAML
        - name: LFG
          spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
        YAML
      registry.size.should eq 1
      registry["LFG"].name.should eq "LFG"
    end

    it "parses a single template at top-level" do
      registry = Chem::TemplateRegistry.new.parse <<-YAML
        name: LFG
        spec: '[N1H3+]-C2-C3-O4-C5(-C6)=O7'
        YAML
      registry.size.should eq 1
      registry["LFG"].name.should eq "LFG"
    end

    it "parses spec aliases" do
      content = <<-YAML
        templates:
          - name: ASD
            spec: '{asd}-CZ'
        aliases:
          asd: 'CX=CY'
        YAML
      registry = Chem::TemplateRegistry.new.parse(content)
      registry["ASD"].atoms.count(&.element.carbon?).should eq 3
    end
  end

  describe "#register" do
    it "creates a residue template with multiple names" do
      registry = Chem::TemplateRegistry.new
      registry.register &.names(%w(LXE EGR)).spec("C1")
      registry.size.should eq 1
      registry["LXE"].should eq registry["EGR"]
    end
  end

  describe "#reject" do
    it "returns a new registry with selected templates" do
      registry = Chem::TemplateRegistry.new
      registry.register &.name("DDA").spec("CA")
      registry.register &.name("DDB").spec("CB")
      registry.register &.name("DDO").spec("OXT")
      registry.reject(&.atoms[0].element.carbon?).to_a.map(&.name).should eq %w(DDO)
    end
  end

  describe "#select" do
    it "returns a new registry with selected templates" do
      registry = Chem::TemplateRegistry.new
      registry.register &.name("DDA").spec("CA")
      registry.register &.name("DDB").spec("CB")
      registry.register &.name("DDO").spec("OXT")
      registry.select(&.atoms[0].element.carbon?).to_a.map(&.name).should eq %w(DDA DDB)
    end
  end

  describe "#spec_alias" do
    it "register an spec alias" do
      registry = Chem::TemplateRegistry.new
      registry.spec_alias "asd", "CX=CY"
      registry.register &.name("ASD").spec("{asd}-CZ").root("CX")
      registry["ASD"].atoms.count(&.element.carbon?).should eq 3
    end
  end

  describe "#size" do
    it "returns the number of templates" do
      registry = Chem::TemplateRegistry.new
      registry.register &.names(%w(DDA DXA)).spec("CA")
      registry.register &.name("DDB").spec("CB")
      registry.register &.names(%w(DDO DXO)).spec("OXT")
      registry.size.should eq 3
    end
  end

  describe "#to_a" do
    it "returns the number of templates" do
      registry = Chem::TemplateRegistry.new
      registry.register &.names(%w(DDA DXA)).spec("CA")
      registry.register &.name("DDB").spec("CB")
      registry.register &.names(%w(DDO DXO)).spec("OXT")
      registry.to_a.map(&.name).should eq %w(DDA DDB DDO)
    end
  end
end

describe Chem do
  describe ".load_template" do
    it "loads and registers a template from structure globally" do
      Chem.load_template "spec/data/mol2/benzene.mol2"
      Chem::TemplateRegistry.default["BEN"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(C1 C2 C3 C4 C5 C6)
    end

    it "loads and registers templates from file globally" do
      tempfile = File.tempfile do |io|
        io << <<-YAML
        name: OIK
        spec: CH-CJ=CK
        YAML
      end
      Chem.load_templates tempfile.path
      Chem::TemplateRegistry.default["OIK"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(CH CJ CK)
    ensure
      tempfile.try &.delete
    end
  end

  describe ".parse_templates" do
    it "parses and registers template globally" do
      Chem.parse_templates <<-YAML
        name: PLF
        spec: PX
        YAML
      Chem::TemplateRegistry.default["PLF"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(PX)
    end
  end

  describe ".template_alias" do
    it "registers a template alias globally" do
      Chem.template_alias "ASD", to: "HOH"
      Chem::TemplateRegistry.default["ASD"].should eq Chem::TemplateRegistry.default["HOH"]
    end
  end
end
