require "./chem/core_ext/**"
require "./chem/err"

require "./chem/linalg"
require "./chem/spatial"

require "./chem/core/bias"
require "./chem/core/bond"
require "./chem/core/bond_array"
require "./chem/core/element"
require "./chem/core/periodic_table"
require "./chem/core/atom"
require "./chem/core/atom_collection"
require "./chem/core/residue"
require "./chem/core/residue_collection"
require "./chem/core/chain"
require "./chem/core/chain_collection"
require "./chem/core/array_view"
require "./chem/core/atom_view"
require "./chem/core/residue_view"
require "./chem/core/chain_view"
require "./chem/core/lattice"
require "./chem/core/structure"
require "./chem/core/structure/*"

require "./chem/protein"
require "./chem/topology"

require "./chem/format_reader"
require "./chem/format_writer"
require "./chem/file_type"
require "./chem/file_format"
require "./chem/formats/*"

module Chem
  class Error < Exception; end
end
