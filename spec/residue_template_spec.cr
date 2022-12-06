require "./spec_helper"

describe Chem::ResidueTemplate do
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
end
