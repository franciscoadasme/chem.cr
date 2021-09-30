require "../spec_helper"

describe Chem::VMD::Writer do
  it "writes a VMD command script" do
    expected = File.read("spec/data/1crn.vmd")
      .gsub("1crn.pdb", Path["spec/data/pdb/1crn.pdb"].expand)
    load_file("1crn.pdb").to_vmd.should eq expected
  end
end
