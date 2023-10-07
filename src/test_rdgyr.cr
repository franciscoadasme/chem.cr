require "./chem.cr"
include Chem

puts "something"

structure1 = Chem::Structure.from_pdb "/mnt/d/Dropbox/comandos_2/github/moltiverse/data/fad_eabf_10/FAD_can/FAD_can_rand_rand_prep.pdb"
structure2 = Chem::Structure.from_pdb "/mnt/d/Dropbox/comandos_2/github/moltiverse/data/fad_eabf_10/FAD_iso/FAD_iso_rand_rand_prep.pdb"

puts structure1.coords.rdgyr()
puts structure2.coords.rdgyr()