require "./bench_helper"

include Chem::Spatial

random = Random.new

structure = Chem::Structure.read "spec/data/pdb/1h1s.pdb"
coords = structure.coords.to_a
kdtree = uninitialized KDTree
pkdtree = uninitialized PeriodicKDTree
points = (0...1000).map do
  Vec3[random.rand(-10.0..70.0), random.rand(100.0), random.rand(100.0)]
end

Benchmark.bm do |bm|
  bm.report("initialization") do
    kdtree = KDTree.new coords
  end

  bm.report("initialization (periodic)") do
    pkdtree = PeriodicKDTree.new coords, structure.cell.not_nil!
  end

  bm.report("query nearest neighbor") do
    points.each do |pt|
      kdtree.nearest pt
    end
  end

  bm.report("query nearest neighbors") do
    points.each do |pt|
      kdtree.neighbors pt, 5
    end
  end

  bm.report("query nearest neighbors (periodic)") do
    points.each do |pt|
      pkdtree.neighbors pt, 5
    end
  end

  bm.report("query nearest neighbors within a threshold") do
    points.each do |pt|
      kdtree.neighbors pt, within: 0.2
    end
  end

  bm.report("query nearest neighbors within a threshold (periodic)") do
    points.each do |pt|
      pkdtree.neighbors pt, within: 0.2
    end
  end

  bm.report("query nearest neighbors within a threshold with block") do
    points.each do |pt|
      kdtree.each_neighbor(pt, within: 0.2) { }
    end
  end

  bm.report("query nearest neighbors within a threshold with block (periodic)") do
    points.each do |pt|
      pkdtree.each_neighbor(pt, within: 0.2) { }
    end
  end
end
