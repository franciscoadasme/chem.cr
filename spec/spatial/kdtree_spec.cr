require "../spec_helper"

describe Chem::Spatial::KDTree do
  describe "#each_neighbor" do
    it "yields each point within the given radius" do
      structure = load_file "1h1s.pdb"
      kdtree = Chem::Spatial::KDTree.new(structure.pos.to_a)
      idxs = [] of Int32
      kdtree.each_neighbor(vec3(19, 32, 44), within: 3.5) do |index, _|
        idxs << index
      end
      idxs.sort!.should eq [1116, 1118, 2538, 2539]
    end
  end

  describe "#nearest" do
    it "returns the nearest point" do
      structure = load_file "1h1s.pdb"
      kdtree = Chem::Spatial::KDTree.new(structure.pos.to_a)
      kdtree.nearest(vec3(22.5, 57.3, 37.63)).should eq 9646
    end
  end

  describe "#neighbors" do
    it "returns the N closest points" do
      kdtree = Chem::Spatial::KDTree.new [
        vec3(4, 3, 0),   # d^2 = 25
        vec3(3, 0, 0),   # d^2 = 9
        vec3(-1, 2, 0),  # d^2 = 5
        vec3(6, 4, 0),   # d^2 = 52
        vec3(3, -5, 0),  # d^2 = 34
        vec3(-2, -5, 0), # d^2 = 29
      ]
      kdtree.neighbors(vec3(0, 0, 0), 2).should eq [2, 1]
    end

    it "returns the N closest points in a large point cloud" do
      structure = load_file "1h1s.pdb"
      kdtree = Chem::Spatial::KDTree.new(structure.pos.to_a)
      kdtree.neighbors(vec3(19, 32, 44), 3).should eq [2539, 1118, 1116]
      kdtree.neighbors(structure.dig('C', 46, "OG").pos, 5).should eq [
        5316, 5315, 7401, 5312, 5317,
      ]
    end

    it "returns the points within the given radius" do
      kdtree = Chem::Spatial::KDTree.new [
        vec3(4, 3, 0),   # 0 d^2 = 25
        vec3(3, 0, 0),   # 1 d^2 = 9
        vec3(-1, 2, 0),  # 2 d^2 = 5
        vec3(6, 4, 0),   # 3 d^2 = 52
        vec3(3, -5, 0),  # 4 d^2 = 34
        vec3(-2, -5, 0), # 5 d^2 = 29
      ]
      kdtree.neighbors(vec3(0, 0, 0), within: 5.5).should eq [2, 1, 0, 5]
    end

    it "returns the points within the given radius in a large point cloud" do
      structure = load_file "1h1s.pdb"
      kdtree = Chem::Spatial::KDTree.new(structure.pos.to_a)
      kdtree.neighbors(vec3(19, 32, 44), within: 3.5).should eq [2539, 1118, 1116, 2538]
      point = structure.dig('C', 1298, "S23").pos
      kdtree.neighbors(point, within: 1.5).should eq [7365, 7366, 7367]
    end
  end
end

describe Chem::Spatial::PeriodicKDTree do
  describe "#neighbors" do
    it "returns the points within the given radius" do
      structure = load_file "AlaIle--wrapped.poscar"
      kdtree = Chem::Spatial::PeriodicKDTree.new(structure.pos.to_a, structure.cell)
      kdtree.neighbors(structure.atoms[4].pos, within: 2.5).should eq [
        4, 27, 29, 3, 24, 16, 28, 31,
      ]
    end

    it "returns the points within the given radius" do
      structure = load_file "5e61--wrapped.poscar"
      kdtree = Chem::Spatial::PeriodicKDTree.new(structure.pos.to_a, structure.cell)
      kdtree.neighbors(structure.atoms[16].pos, within: 2).should eq [
        16, 85, 86, 87, 15,
      ]
    end

    it "returns neighbors in off-center non-wrapped point cloud" do
      structure = load_file "5e61--off-center.poscar"
      n9 = structure.atoms.find!("N9")   # 174
      c42 = structure.atoms.find!("C42") # 41
      c43 = structure.atoms.find!("C43") # 42
      h64 = structure.atoms.find!("H64") # 127
      h65 = structure.atoms.find!("H65") # 128

      kdtree = Chem::Spatial::PeriodicKDTree.new(structure.pos.to_a, structure.cell)
      kdtree.neighbors(c42.pos, within: 1.82).should eq [41, 127, 128, 174, 42]
      kdtree.neighbors(h64.pos, within: 1.82).should eq [127, 41, 128]
    end
  end
end

private def naive_neighbor_search(points, query, n : Int)
  points
    .map_with_index { |vec, i| {vec, i} }
    .sort_by! { |vec, _| (vec - query).abs2 }
    .first(n)
    .map(&.[1])
end

private def naive_neighbor_search(points, query, radius : Float)
  points
    .map_with_index { |vec, i| {vec, i} }
    .select! { |vec, _| (vec - query).abs <= radius }
    .sort_by! { |vec, _| (vec - query).abs2 }
    .map(&.[1])
end

private def naive_neighbor_search(points, cell, query, radius : Float)
  mirrored_points = [] of {Chem::Spatial::Vec3, Int32}
  bi, bj, bk = cell.basisvec
  points.each_with_index do |vec, ii|
    (-1..1).each do |i|
      (-1..1).each do |j|
        (-1..1).each do |k|
          mirrored_points << {vec + i * bi + j * bj + k * bk, ii}
        end
      end
    end
  end
  mirrored_points
    .select! { |vec, _| (vec - query).abs <= radius }
    .sort_by! { |vec, _| (vec - query).abs2 }
    .map(&.[1])
end
