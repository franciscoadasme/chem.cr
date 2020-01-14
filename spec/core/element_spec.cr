require "../spec_helper"

describe Chem::Element do
  describe "#inspect" do
    it "returns a delimited string representation" do
      Chem::PeriodicTable::Br.inspect.should eq "<Element Br(35)>"
    end
  end
end
