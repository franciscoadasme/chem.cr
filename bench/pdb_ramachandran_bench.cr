require "./bench_helper"

st = Chem::Structure.read "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    angles = st.residues.map do |residue|
      {residue.phi? || Float64::NAN, residue.psi? || Float64::NAN}
    end
  end
end
