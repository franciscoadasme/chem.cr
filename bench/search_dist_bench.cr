require "../src/chem/analysis"
require "../src/chem/geometry/vector"
require "../src/chem/pdb"
require "./search_dist_helper"
require "benchmark"

alias KDTree = Chem::Analysis::Spatial::KDTree
alias Vector = Chem::Geometry::Vector

atoms = Chem::PDB.parse("spec/data/1h1s.pdb").atoms
atoms_as_a = atoms.to_a
tree = KDTree.new atoms

cr_data = Hash.zip (0...atoms.size).to_a.map(&.to_f), atoms.map(&.coords.to_a)
cr_tree = Crystalline::KDTree(Float64).new cr_data

puts "Nearest neighbors"
Benchmark.ips do |x|
  point = Vector.origin
  # point = Vector[19, 32, 44]
  point_a = point.to_a

  x.report("crystalline") do
    cr_tree.find_nearest point_a, k_nearest: 2
  end

  x.report("kdtree") do
    tree.nearest to: point, neighbors: 2
  end

  x.report("naive_search") do
    naive_search atoms, point, 2
  end

  x.report("sort_search") do
    sort_search atoms_as_a, point, 2
  end
end

puts
puts "Range (distance) search"
Benchmark.ips do |x|
  point = Vector[19, 32, 44]
  point_a = point.to_a

  x.report("crystalline") do
    cr_tree.find_nearest point_a, 3.5
  end

  x.report("kdtree (array)") do
    tree.nearest to: point, within: 3.5
  end

  x.report("kdtree (yield)") do
    tree.nearest to: point, within: 3.5 { }
  end
end
