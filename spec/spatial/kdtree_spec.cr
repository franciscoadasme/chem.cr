require "../spec_helper"

describe Chem::Spatial::KDTree do
  context "toy example" do
    st = Chem::Structure.build do
      atom vec3(4, 3, 0)   # d^2 = 25
      atom vec3(3, 0, 0)   # d^2 = 9
      atom vec3(-1, 2, 0)  # d^2 = 5
      atom vec3(6, 4, 0)   # d^2 = 52
      atom vec3(3, -5, 0)  # d^2 = 34
      atom vec3(-2, -5, 0) # d^2 = 29
    end
    kdtree = Chem::Spatial::KDTree.new st

    describe "#neighbors" do
      it "returns the N closest atoms sorted by proximity" do
        atoms = kdtree.neighbors of: vec3(0, 0, 0), count: 2
        atoms.map(&.serial).should eq [3, 2]
      end

      it "returns the atoms within the given radius sorted by proximity" do
        atoms = kdtree.neighbors of: vec3(0, 0, 0), within: 5.5
        atoms.map(&.serial).should eq [3, 2, 1, 6]
      end
    end
  end

  context "real example" do
    st = load_file "1h1s.pdb"
    kdtree = Chem::Spatial::KDTree.new st, periodic: false

    describe "#each_neighbor" do
      it "yields each atom within the given radius of a point" do
        atoms = [] of Chem::Atom
        kdtree.each_neighbor(of: vec3(19, 32, 44), within: 3.5) do |atom, _|
          atoms << atom
        end
        atoms.map(&.serial).sort!.should eq [1117, 1119, 9125, 9126]
      end

      it "yields each atom within the given radius of an atom" do
        atoms = [] of Chem::Atom
        kdtree.each_neighbor(of: st['C'][123]["CG1"], within: 2.61) do |atom, _|
          atoms << atom
        end
        atoms.map(&.serial).should eq [5461, 5464, 5466]
      end
    end

    describe "#nearest" do
      it "returns the nearest atom to a point" do
        kdtree.nearest(to: vec3(22.5, 57.3, 37.63)).serial.should eq 9651
      end

      it "returns the nearest atom to an atom" do
        kdtree.nearest(to: st['A'][35]["CD1"]).serial.should eq 280
      end
    end

    describe "#neighbors" do
      it "returns the N closest atoms to a point sorted by proximity" do
        atoms = kdtree.neighbors of: vec3(19, 32, 44), count: 3
        atoms.map(&.serial).should eq [9126, 1119, 1117]
      end

      it "returns the N closest atoms to an atom sorted by proximity" do
        atoms = kdtree.neighbors of: st['C'][46]["OG"], count: 5
        atoms.map(&.serial).should eq [4837, 9489, 4834, 4839, 4835]
      end

      it "returns the atoms within the given radius of a point sorted by proximity" do
        atoms = kdtree.neighbors of: vec3(19, 32, 44), within: 3.5
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
        kdtree = Chem::Spatial::KDTree.new structure, radius: 2.5
        atoms = kdtree.neighbors of: structure.atoms[4], within: 2.5
        atoms.map(&.serial).sort!.should eq [4, 17, 25, 28, 29, 30, 32]
      end

      it "returns the atoms within the given radius of a point sorted by proximity" do
        structure = load_file "5e61--wrapped.poscar"
        kdtree = Chem::Spatial::KDTree.new structure, radius: 2
        atoms = kdtree.neighbors of: structure.atoms[16], within: 2
        atoms.map(&.serial).should eq [86, 87, 88, 16]
      end
    end
  end

  it "generates adjacent points within the given radius" do
    structure = load_file "5e61--off-center.poscar"
    n9 = structure.atoms["N9"]
    c42 = structure.atoms["C42"]
    c43 = structure.atoms["C43"]
    h64 = structure.atoms["H64"]
    h65 = structure.atoms["H65"]

    max_covalent_dis = 1.82
    kdtree = Chem::Spatial::KDTree.new(structure, radius: max_covalent_dis)
    kdtree.neighbors(c42, within: max_covalent_dis).should eq [h64, h65, n9, c43]
    kdtree.neighbors(h64, within: max_covalent_dis).should eq [c42, h65]
  end

  describe "#nearest_with_distance" do
    it "returns closest neighbor + distance to a point" do
      structure = Chem::Structure.build do
        cell 2, 2, 2
        atom :C, vec3(1, 1, 1)
        atom :H, vec3(1.5, 0.5, 0.5)
      end
      c, h = structure.atoms

      kdtree = Chem::Spatial::KDTree.new structure
      kdtree.nearest_with_distance(vec3(0, 0, 0)).should eq({h, 0.75})
      kdtree.nearest_with_distance(vec3(1, 1, 1)).should eq({c, 0})
      kdtree.nearest_with_distance(vec3(2, 0, 0)).should eq({h, 0.75})
    end

    it "returns closest neighbor + distance to an atom" do
      structure = Chem::Structure.build do
        cell 2, 2, 2
        atom :C, vec3(1, 1, 1)
        atom :H, vec3(1.5, 0.5, 0.5)
      end
      c, h = structure.atoms

      kdtree = Chem::Spatial::KDTree.new structure
      kdtree.nearest_with_distance(c).should eq({h, 0.75})
      kdtree.nearest_with_distance(h).should eq({c, 0.75})
    end
  end

  describe "#neighbors_with_distance" do
    it "returns N closest neighbors + distances to a point" do
      structure = Chem::Structure.build do
        cell 2, 2, 2
        atom :C, vec3(1, 1, 1)
        atom :H, vec3(1.5, 0.5, 0.5)
      end
      structure.to_pdb "output.pdb"
      c, h = structure.atoms

      kdtree = Chem::Spatial::KDTree.new structure
      kdtree.neighbors_with_distance(vec3(0, 0, 0), n: 2).should eq [{h, 0.75}, {h, 2.75}]
      kdtree.neighbors_with_distance(vec3(1, 1, 1), n: 2).should eq [{c, 0}, {h, 0.75}]
      kdtree.neighbors_with_distance(vec3(2, 0, 0), n: 2).should eq [{h, 0.75}, {c, 3.0}]
      neighbors = kdtree.neighbors_with_distance(vec3(0.141, 1.503, 1.801), n: 2)
      neighbors.map(&.[0]).should eq [c, h]
      neighbors.map(&.[1]).should be_close [1.633, 1.893], 1e-3
    end

    it "returns N closest neighbors + distances to an atom" do
      structure = Chem::Structure.build do
        cell 2, 2, 2
        atom :C, vec3(1, 1, 1)
        atom :H, vec3(1.5, 0.5, 0.5)
      end
      c, h = structure.atoms

      kdtree = Chem::Spatial::KDTree.new structure
      kdtree.neighbors_with_distance(c, n: 2).should eq [{h, 0.75}, {h, 2.75}]
    end
  end
end
