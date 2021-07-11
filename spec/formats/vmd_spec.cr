require "../spec_helper"

describe Chem::VMD::Writer do
  it "writes a VMD command script" do
    expected = File.read("spec/data/1crn.vmd")
    load_file("1crn.pdb").to_vmd(source_path: "pdb/1crn.pdb").should eq expected
  end
end
