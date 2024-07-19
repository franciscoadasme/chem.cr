require "./bench_helper"

st = Chem::Structure.read "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    r1 = st.dig 'A', 50
    r2 = st.dig 'A', 60
    min_dist = r1.atoms.min_of do |a1|
      r2.atoms.min_of { |a2| Chem::Spatial.distance2 a1, a2 }
    end
  end
end
