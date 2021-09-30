require "../spec_helper"

describe Chem::Protein::Stride::Writer do
  it "writes in the STRIDE file format" do
    expected = File.read("spec/data/1crn.stride")
      .gsub(/1crn.pdb A +/, "#{Path["spec/data/pdb/1crn.pdb"].expand} A".ljust(70))
    load_file("1crn.pdb").to_stride.should eq expected
  end
end
