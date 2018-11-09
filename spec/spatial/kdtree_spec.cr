require "../../spec_helper"

alias KDTree = Chem::Spatial::KDTree

describe Chem::Spatial::KDTree do
  context "toy example" do
    system = Chem::System.build do
      atom at: {4, 3, 0}   # d^2 = 25
      atom at: {3, 0, 0}   # d^2 = 9
      atom at: {-1, 2, 0}  # d^2 = 5
      atom at: {6, 4, 0}   # d^2 = 52
      atom at: {3, -5, 0}  # d^2 = 34
      atom at: {-2, -5, 0} # d^2 = 29
    end

    tree = KDTree.new system.atoms

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.origin, within: 5.5).should eq [3, 2, 1, 6]
      end
    end

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.origin, neighbors: 2).should eq [3, 2]
      end
    end
  end

  context "real example" do
    system = PDB.parse_first "spec/data/pdb/1h1s.pdb"
    tree = KDTree.new system.atoms

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], neighbors: 1).should eq [9126]
      end
    end

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], within: 3.5).should eq [9126, 1119, 1117, 9125]
      end

      it "works" do
        atom_indices = [] of Int32
        tree.nearest(to: Vector[19, 32, 44], within: 3.5) do |atom_index, distance|
          atom_indices << atom_index
        end
        atom_indices.sort!.should eq [1117, 1119, 9125, 9126]
      end
    end
  end
end
