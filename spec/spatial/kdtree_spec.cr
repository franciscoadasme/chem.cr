require "../spec_helper"

alias KDTree = Chem::Spatial::KDTree

describe Chem::Spatial::KDTree do
  context "toy example" do
    st = Chem::Structure.build do
      atom V[4, 3, 0]   # d^2 = 25
      atom V[3, 0, 0]   # d^2 = 9
      atom V[-1, 2, 0]  # d^2 = 5
      atom V[6, 4, 0]   # d^2 = 52
      atom V[3, -5, 0]  # d^2 = 34
      atom V[-2, -5, 0] # d^2 = 29
    end
    kdtree = KDTree.new st

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
    st = load_file "1h1s.pdb"
    kdtree = KDTree.new st, periodic: false

    describe "#each_neighbor" do
      it "yields each atom within the given radius of a point" do
        atoms = [] of Atom
        kdtree.each_neighbor(of: V[19, 32, 44], within: 3.5) do |atom, _|
          atoms << atom
        end
        atoms.map(&.serial).sort!.should eq [1117, 1119, 9125, 9126]
      end

      it "yields each atom within the given radius of an atom" do
        atoms = [] of Atom
        kdtree.each_neighbor(of: st['C'][123]["CG1"], within: 2.61) do |atom, _|
          atoms << atom
        end
        atoms.map(&.serial).should eq [5461, 5464, 5466]
      end
    end

    describe "#nearest" do
      it "returns the nearest atom to a point" do
        kdtree.nearest(to: V[22.5, 57.3, 37.63]).serial.should eq 9651
      end

      it "returns the nearest atom to an atom" do
        kdtree.nearest(to: st['A'][35]["CD1"]).serial.should eq 280
      end
    end

    describe "#neighbors" do
      it "returns the N closest atoms to a point sorted by proximity" do
        atoms = kdtree.neighbors of: V[19, 32, 44], count: 3
        atoms.map(&.serial).should eq [9126, 1119, 1117]
      end

      it "returns the N closest atoms to an atom sorted by proximity" do
        atoms = kdtree.neighbors of: st['C'][46]["OG"], count: 5
        atoms.map(&.serial).should eq [4837, 9489, 4834, 4839, 4835]
      end

      it "returns the atoms within the given radius of a point sorted by proximity" do
        atoms = kdtree.neighbors of: V[19, 32, 44], within: 3.5
        atoms.map(&.serial).should eq [9126, 1119, 1117, 9125]
      end

      it "returns the atoms within the given radius of a point sorted by proximity" do
        atoms = kdtree.neighbors of: st['C'][1298]["S23"], within: 1.5
        atoms.map(&.serial).should eq [9001, 9002]
      end
    end
  end

  context "periodic" do
    describe "#neighbors" do
      it "returns the atoms within the given radius of a point sorted by proximity" do
        structure = load_file "AlaIle--wrapped.poscar"
        kdtree = KDTree.new structure, radius: 2.5
        atoms = kdtree.neighbors of: structure.atoms[4], within: 2.5
        atoms.map(&.serial).sort!.should eq [4, 17, 25, 28, 29, 30, 32]
      end

      it "returns the atoms within the given radius of a point sorted by proximity" do
        structure = load_file "5e61--wrapped.poscar"
        kdtree = KDTree.new structure, radius: 2
        atoms = kdtree.neighbors of: structure.atoms[16], within: 2
        atoms.map(&.serial).should eq [86, 87, 88, 16]
      end
    end
  end

  describe "#nearest_with_distance" do
    it "returns closest neighbor + distance to a point" do
      structure = Structure.build do
        lattice 2, 2, 2
        atom :C, V[1, 1, 1]
        atom :H, V[1.5, 0.5, 0.5]
      end
      c, h = structure.atoms

      kdtree = KDTree.new structure
      kdtree.nearest_with_distance(V[0, 0, 0]).should eq({h, 0.75})
      kdtree.nearest_with_distance(V[1, 1, 1]).should eq({c, 0})
      kdtree.nearest_with_distance(V[2, 0, 0]).should eq({h, 0.75})
    end

    it "returns closest neighbor + distance to an atom" do
      structure = Structure.build do
        lattice 2, 2, 2
        atom :C, V[1, 1, 1]
        atom :H, V[1.5, 0.5, 0.5]
      end
      c, h = structure.atoms

      kdtree = KDTree.new structure
      kdtree.nearest_with_distance(c).should eq({h, 0.75})
      kdtree.nearest_with_distance(h).should eq({c, 0.75})
    end
  end

  describe "#neighbors_with_distance" do
    it "returns N closest neighbors + distances to a point" do
      structure = Structure.build do
        lattice 2, 2, 2
        atom :C, V[1, 1, 1]
        atom :H, V[1.5, 0.5, 0.5]
      end
      c, h = structure.atoms

      kdtree = KDTree.new structure
      kdtree.neighbors_with_distance(V[0, 0, 0], n: 2).should eq [{h, 0.75}, {h, 2.75}]
      kdtree.neighbors_with_distance(V[1, 1, 1], n: 2).should eq [{c, 0}, {h, 0.75}]
      kdtree.neighbors_with_distance(V[2, 0, 0], n: 2).should eq [{h, 0.75}, {c, 3.0}]
      neighbors = kdtree.neighbors_with_distance(V[0.141, 1.503, 1.801], n: 2)
      neighbors.map(&.[0]).should eq [c, h]
      neighbors.map(&.[1]).should be_close [1.633, 1.893], 1e-3
    end

    it "returns N closest neighbors + distances to an atom" do
      structure = Structure.build do
        lattice 2, 2, 2
        atom :C, V[1, 1, 1]
        atom :H, V[1.5, 0.5, 0.5]
      end
      c, h = structure.atoms

      kdtree = KDTree.new structure
      kdtree.neighbors_with_distance(c, n: 2).should eq [{h, 0.75}, {h, 2.75}]
    end
  end
end
