require "./bench_helper"

alias KDTree = Chem::Spatial::KDTree
alias V = Chem::Spatial::Vec3

random = Random.new

structure = Chem::Structure.read "spec/data/pdb/1h1s.pdb"
kdtree = uninitialized KDTree
pkdtree = uninitialized KDTree
points = (0...1000).map do
  V[random.rand(-10.0..70.0), random.rand(100.0), random.rand(100.0)]
end

Benchmark.bm do |bm|
  bm.report("initialization") do
    kdtree = KDTree.new structure
  end

  bm.report("initialization (periodic)") do
    pkdtree = KDTree.new structure, periodic: true
  end

  bm.report("query nearest neighbor") do
    points.each do |pt|
      kdtree.nearest to: pt
    end
  end

  bm.report("query nearest neighbors") do
    points.each do |pt|
      kdtree.neighbors of: pt, count: 5
    end
  end

  bm.report("query nearest neighbors (periodic)") do
    points.each do |pt|
      pkdtree.neighbors of: pt, count: 5
    end
  end

  bm.report("query nearest neighbors within a threshold") do
    points.each do |pt|
      kdtree.neighbors of: pt, within: 0.2
    end
  end

  bm.report("query nearest neighbors within a threshold (periodic)") do
    points.each do |pt|
      pkdtree.neighbors of: pt, within: 0.2
    end
  end

  bm.report("query nearest neighbors within a threshold with block") do
    points.each do |pt|
      kdtree.each_neighbor of: pt, within: 0.2 { }
    end
  end

  bm.report("query nearest neighbors within a threshold with block (periodic)") do
    points.each do |pt|
      pkdtree.each_neighbor of: pt, within: 0.2 { }
    end
  end
end
