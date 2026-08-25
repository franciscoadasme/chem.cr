require "./bench_helper"

structures = Array(Chem::Structure).read data_file("1htq.pdb")
atoms = structures[0].atoms.select { |atom| atom.protein? && atom.name == "CA" }
other = structures[1].atoms.select { |atom| atom.protein? && atom.name == "CA" }

bench("RMSD(minimize)") do
  atoms.rmsd other, minimize: true
end

bench("Align") do
  other.pos.align_to atoms.pos
end
