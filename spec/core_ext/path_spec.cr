require "../spec_helper"

describe Path do
  describe "#with_ext" do
    it "changes extension" do
      Path["/foo/bar.xyz"].with_ext(".pdb").should eq Path["/foo/bar.pdb"]
    end

    it "adds extension if missing" do
      Path["/foo/bar"].with_ext(".xyz").should eq Path["/foo/bar.xyz"]
    end
  end
end
