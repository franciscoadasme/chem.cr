require "./dssp/*"

# Pure Crystal implementation of the Dictionary of Protein Secondary Structure (DSSP)
# algorithm (Kabsch, W.; Sander, C. *Biopolymers* **1983**, *22* (12), 2577–2637.
# [doi:10.1002/bip.360221211][1]).
#
# This implementation is based on the `mkdssp` program, version 3.0.5, written by
# Maarten L. Hekkelman, currently maintained by Coos Baakman, Jon Black, and Wouter
# Touw, and distributed under the Boost Software license at the
# [github.com/cmbi/xssp][2] repository.
#
# Consider that, according to the algorithm, residues that do not contain backbone
# atoms, namely, "N", "CA", "C", and "O", are ignored. Therefore, non-standard amino
# acids are considered during the assignment as long as they contain such atoms.
# Otherwise, they will be considered as protein gaps, which may alter the secondary
# structure of surrounding residues.
#
# Note that some differences may be expected with the output of `mkdssp` due to:
#
# - `mkdssp` does not handle well alternate conformations in PDB files, sometimes
#   discarding entire aminoacids.
# - `mkdssp` detects chain breaks by checking non-consecutive numbers of neighboring
#   residues. This may fail when residues *i* and *i + 1* are not actually bonded, or
#   when residue numbers are not consecutive. This implementation instead checks that
#   the C(*i*)–N(*i*+1) bond length is within covalent distance.
#
# NOTE: This implementation of DSSP is currently 50% slower than pure C++ solutions, so
# keep this in mind when assigning the secondary structure of many structures.
#
# [1]: http://dx.doi.org/10.1002/bip.360221211
# [2]: http://github.com/cmbi/xssp
module Chem::Protein::DSSP
  extend self

  MAX_CN_BOND_SQUARED_DIST = (0.76 + 0.71 + 0.3)**2 # DSSP paper suggest 2.5 A
  MIN_CA_SQUARED_DIST      =      81
  HBOND_COUPLING_FACTOR    = -27.888
  HBOND_ENERGY_CUTOFF      =    -0.5
  HBOND_MIN_ENERGY         =    -9.9

  # Assigns the secondary structure to each residue according to the DSSP algorithm
  #
  # NOTE: It resets the existing secondary structure values prior to running DSSP
  #
  # ```
  # st = Structure.read "1aho.pdb"
  # Chem::Protein::DSSP.assign_secondary_structure st
  # st['A'][20].secondary_structure # => HelixAlpha
  # ```
  def assign_secondary_structure(residues : ResidueCollection) : Nil
    Calculator.new(residues).assign!
  end
end
