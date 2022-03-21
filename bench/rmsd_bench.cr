require "./bench_helper"

structures = Array(Chem::Structure).read data_file("1htq.pdb")
atoms = structures[0].atoms.select { |atom| atom.protein? && atom.name == "CA" }
other = structures[1].atoms.select { |atom| atom.protein? && atom.name == "CA" }

bench("RMSD(minimize)") do
  Chem::Spatial.rmsd atoms, other, minimize: true
end

bench("Align") do
  Chem::Spatial.align other, atoms
end
