require "./bench_helper"

st = Chem::PDB.read_first "bench/data/1ake.pdb"

Benchmark.bm do |bm|
  bm.report("1AKE (3818 atoms)") do
    ary = [] of Tuple(Float64, Float64)
    st.each_residue do |residue|
      ary << residue.ramachandran_angles
    rescue Chem::Error
      ary << {Float64::NAN, Float64::NAN}
    end
  end
end
