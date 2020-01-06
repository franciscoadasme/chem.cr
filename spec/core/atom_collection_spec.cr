require "../spec_helper"

describe Chem::AtomCollection do
  describe "#fragments" do
    it "returns the fragments (1)" do
      structure = Chem::Structure.read "spec/data/poscar/5e61--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      structure.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (2)" do
      structure = Chem::Structure.read "spec/data/poscar/5e61--unwrapped.poscar"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      structure.fragments.map(&.size).should eq [100, 100]
    end

    it "returns the fragments (3)" do
      structure = Chem::Structure.read "spec/data/xyz/k2p_pore_b.xyz"
      builder = Chem::Structure::Builder.new structure
      builder.guess_bonds_from_geometry
      structure.fragments.map(&.size).sort!.should eq [1, 1, 1, 1, 304, 334]
    end
  end
end
