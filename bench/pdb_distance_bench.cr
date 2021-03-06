require "./bench_helper"

st = Chem::Structure.read "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    r1 = st.dig 'A', 50
    r2 = st.dig 'A', 60
    min_dist = r1.each_atom.min_of do |a1|
      r2.each_atom.min_of { |a2| Chem::Spatial.squared_distance a1, a2 }
    end
  end
end
