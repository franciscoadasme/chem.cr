require "../spec_helper"

describe Chem::AtomCollection do
  describe "#fragments" do
    it "returns the fragments (1)" do
      load_file("5e61--unwrapped.poscar", topology: :bonds).fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (2)" do
      load_file("5e61--unwrapped.poscar", topology: :bonds).fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (3)" do
      expected = [1, 1, 1, 1, 304, 334]
      load_file("k2p_pore_b.xyz", topology: :bonds).fragments.map(&.size).sort!.should eq expected
    end
  end
end
