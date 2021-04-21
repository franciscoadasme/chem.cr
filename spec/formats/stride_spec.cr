require "../spec_helper"

describe Chem::XYZ::Writer do
  it "writes in the STRIDE file format" do
    structure = load_file "1crn.pdb"
    structure.to_stride(source_file: "1crn.pdb").should eq File.read("spec/data/1crn.stride")
  end
end
