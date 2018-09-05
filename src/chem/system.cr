require "./bias"
require "./lattice"
require "./protein/experiment"
require "./protein/sequence"
require "./topology/atom_collection"

module Chem
  class System
    include AtomCollection

    getter biases = [] of Chem::Bias
    getter experiment : Protein::Experiment?
    getter lattice : Lattice?
    getter sequence : Protein::Sequence?
    getter title : String

    def size
      @atoms.size
    end
  end
end
