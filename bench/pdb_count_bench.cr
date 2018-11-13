require "./bench_helper"

st = Chem::PDB.read_first "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    st.each_residue.count &.name.==("ALA")
  end
end
