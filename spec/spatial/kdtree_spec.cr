require "../../spec_helper"

alias KDTree = Chem::Spatial::KDTree

describe Chem::Spatial::KDTree do
  context "toy example" do
    st = Chem::Structure.build do
      atom at: {4, 3, 0}   # d^2 = 25
      atom at: {3, 0, 0}   # d^2 = 9
      atom at: {-1, 2, 0}  # d^2 = 5
      atom at: {6, 4, 0}   # d^2 = 52
      atom at: {3, -5, 0}  # d^2 = 34
      atom at: {-2, -5, 0} # d^2 = 29
    end

    tree = KDTree.new st.atoms

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.zero, within: 5.5).map(&.serial).should eq [3, 2, 1, 6]
      end
    end

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.zero, neighbors: 2).map(&.serial).should eq [3, 2]
      end
    end
  end

  context "real example" do
    st = PDB.read_first "spec/data/pdb/1h1s.pdb"
    tree = KDTree.new st.atoms

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], neighbors: 1)
          .map(&.serial).should eq [9126]
      end
    end

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], within: 3.5)
          .map(&.serial).should eq [9126, 1119, 1117, 9125]
      end

      it "works" do
        atom_numbers = [] of Int32
        tree.nearest(to: Vector[19, 32, 44], within: 3.5) do |atom, distance|
          atom_numbers << atom.serial
        end
        atom_numbers.sort!.should eq [1117, 1119, 9125, 9126]
      end
    end
  end
end
