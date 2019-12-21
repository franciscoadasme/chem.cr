require "../spec_helper"

describe Chem::Chain do
  describe "#new" do
    it "fails with non-alphanumeric id" do
      expect_raises ArgumentError, "Non-alphanumeric chain id" do
        Chain.new '[', Structure.new
      end
    end
  end
end
