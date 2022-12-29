require "./spec_helper"

describe Chem::Templates do
  describe ".alias" do
    it "registers a template alias globally" do
      Chem::Templates.alias "ASD", to: "HOH"
      Chem::Templates::Registry.default["ASD"].should eq Chem::Templates::Registry.default["HOH"]
    end
  end

  describe ".load" do
    it "loads and registers a template from structure globally" do
      Chem::Templates.load "spec/data/mol2/benzene.mol2"
      Chem::Templates::Registry.default["BEN"].atoms
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
      Chem::Templates.load tempfile.path
      Chem::Templates::Registry.default["OIK"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(CH CJ CK)
    ensure
      tempfile.try &.delete
    end
  end

  describe ".parse" do
    it "parses and registers template globally" do
      Chem::Templates.parse <<-YAML
        name: PLF
        spec: PX
        YAML
      Chem::Templates::Registry.default["PLF"].atoms
        .select(&.element.heavy?)
        .map(&.name).should eq %w(PX)
    end
  end
end
