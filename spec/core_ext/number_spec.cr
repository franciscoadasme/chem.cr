require "../spec_helper"

describe Number do
  describe "#bohrs" do
    it "returns the length in angstroms from bohrs" do
      1.bohr.should be_close 0.529177, 1e-5
      0.231.bohrs.should be_close 0.1222399, 1e-5
      1.88973.bohrs.should be_close 1, 1e-5
    end
  end

  describe "#to_bohrs" do
    it "returns the length in bohrs from angstroms" do
      1.to_bohrs.should be_close 1.88973, 1e-5
      2.152.to_bohrs.should be_close 4.0666906, 1e-5
      0.529177.to_bohrs.should be_close 1, 1e-5
    end
  end
end
