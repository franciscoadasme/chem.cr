require "../spec_helper"

describe Chem::Protein::Stride::Writer do
  it "writes in the STRIDE file format" do
    expected = File.read(spec_file("1crn.stride"))
    load_file("1crn.pdb").to_stride.should eq expected
  end
end
