require "../src/chem/pdb"
require "./search_dist_helper"
require "benchmark"

Benchmark.bm do |x|
  x.report("1CRN (327 atoms)") do
    Chem::PDB.parse "bench/data/1crn.pdb"
  end

  x.report("3JYV (57,327 atoms)") do
    Chem::PDB.parse "bench/data/3jyv.pdb"
  end

  x.report("1HTQ (978,720 atoms)") do
    Chem::PDB.parse "bench/data/1htq.pdb"
  end
end
