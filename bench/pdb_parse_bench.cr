require "./bench_helper"
require "./search_dist_helper"

Benchmark.bm do |x|
  x.report("1CRN (327 atoms)") do
    Chem::Structure.from_pdb "bench/data/1crn.pdb"
  end

  x.report("3JYV (57,327 atoms)") do
    Chem::Structure.from_pdb "bench/data/3jyv.pdb"
  end

  x.report("1HTQ (978,720 atoms)") do
    Chem::Structure.from_pdb "bench/data/1htq.pdb"
  end
end
