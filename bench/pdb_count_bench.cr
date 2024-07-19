require "./bench_helper"

st = Chem::Structure.read "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    st.residues.count &.name.==("ALA")
  end
end
