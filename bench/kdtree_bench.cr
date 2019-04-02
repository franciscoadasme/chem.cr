require "./bench_helper"

alias KDTree = Chem::Spatial::KDTree
alias V = Chem::Spatial::Vector

random = Random.new

atoms = Chem::PDB.read_first("spec/data/pdb/1h1s.pdb").atoms
kdtree = uninitialized KDTree
points = (0...1000).map do
  V[random.rand(-10.0..70.0), random.rand(100.0), random.rand(100.0)]
end

Benchmark.bm do |bm|
  bm.report("initialization") do
    kdtree = KDTree.new atoms
  end

  bm.report("query nearest neighbor") do
    points.each do |pt|
      kdtree.nearest to: pt
    end
  end

  bm.report("query nearest neighbors within a threshold") do
    points.each do |pt|
      kdtree.nearest to: pt, within: 0.2
    end
  end

  bm.report("query nearest neighbors within a threshold with block") do
    points.each do |pt|
      kdtree.nearest to: pt, within: 0.2 { }
    end
  end
end
