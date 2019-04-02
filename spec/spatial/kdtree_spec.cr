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
    kdtree = KDTree.new st.atoms

    describe "#neighbors" do
      it "returns the N closest atoms sorted by proximity" do
        atoms = kdtree.neighbors of: V.origin, count: 2
        atoms.map(&.serial).should eq [3, 2]
      end

      it "returns the atoms within the given radius sorted by proximity" do
        atoms = kdtree.neighbors of: V.origin, within: 5.5
        atoms.map(&.serial).should eq [3, 2, 1, 6]
      end
    end
  end

  context "real example" do
    st = PDB.read_first "spec/data/pdb/1h1s.pdb"
    kdtree = KDTree.new st.atoms

    describe "#each_neighbor" do
      it "yields each atom within the given radius" do
        atoms = [] of Atom
        kdtree.each_neighbor(of: V[19, 32, 44], within: 3.5) do |atom, _|
          atoms << atom
        end
        atoms.map(&.serial).sort!.should eq [1117, 1119, 9125, 9126]
      end
    end

    describe "#nearest" do
      it "returns the nearest atom" do
        kdtree.nearest(to: V[22.5, 57.3, 37.63]).serial.should eq 9651
      end
    end

    describe "#neighbors" do
      it "returns the N closest atoms sorted by proximity" do
        atoms = kdtree.neighbors of: V[19, 32, 44], count: 3
        atoms.map(&.serial).should eq [9126, 1119, 1117]
      end

      it "returns the atoms within the given radius sorted by proximity" do
        atoms = kdtree.neighbors of: V[19, 32, 44], within: 3.5
        atoms.map(&.serial).should eq [9126, 1119, 1117, 9125]
      end
    end
  end
end
