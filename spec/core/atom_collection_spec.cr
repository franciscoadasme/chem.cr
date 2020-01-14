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

    it "returns fragments limited to the selected atoms " do
      atoms = load_file("5e5v.pdb", topology: :bonds).atoms
      atoms[0..205].fragments.map(&.size).should eq [103, 103]
      atoms[0..150].fragments.map(&.size).should eq [103, 48]
      atoms[0..50].fragments.map(&.size).should eq [51]
      atoms[0..0].fragments.map(&.size).should eq [1]

      ary = atoms[0..10].to_a
      ary.concat atoms[150..158] # => O=C(i)-N(i+1)-H-CA, sidechain(i) (no CA(i)-CB)
      ary.concat atoms[210..220] # => H1, H2, HOH, HOH, HOH
      Chem::AtomView.new(ary).fragments.map(&.size).should eq [11, 5, 4, 1, 1, 3, 3, 3]
    end
  end
end
