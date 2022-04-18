require "./templates/all"

class Chem::Topology::Perception
  MAX_CHAINS = 62 # chain id is alphanumeric: A-Z, a-z or 0-9

  def initialize(@structure : Structure)
  end

  # Guesses residues from existing bonds.
  #
  # Atoms are split in fragments, where each fragment is mapped to a list of residues.
  # Then, fragments are divided into polymers (e.g., peptide) and non-polymer
  # fragments (e.g., water), where residues assigned to the latter are grouped
  # together by their kind (i.e., protein, ion, solvent, etc.). Finally, polymer
  # fragments and residues grouped by kind are assigned to their own unique chain as
  # long as there are less residue groups than the chain limit (62), otherwise all
  # residues are assigned to the same chain.
  def guess_residues : Nil
    matches_per_fragment = detect_residues @structure.atoms
    builder = Structure::Builder.new @structure.clear
    matches_per_fragment.each do |matches|
      builder.chain do
        matches.each do |m|
          residue = builder.residue m.resname
          residue.kind = m.reskind
          m.each_atom do |atom, atom_name|
            atom.name = atom_name
            atom.residue = residue
          end
        end
      end
    end
    @structure.topology.renumber_residues_by_connectivity split_chains: false
    assign_residue_types
  end

  private def assign_residue_types : Nil
    return unless bond_t = @structure.topology.link_bond
    @structure.each_residue do |residue|
      next if residue.type
      types = residue
        .bonded_residues(bond_t, forward_only: false, strict: false)
        .map(&.kind)
        .uniq!
        .reject!(&.other?)
      residue.kind = types.size == 1 ? types[0] : Residue::Kind::Other
    end
  end

  private def detect_residues(atoms : AtomView) : Array(Array(MatchData))
    fragments = [] of Array(MatchData)
    atoms.each_fragment do |frag|
      detector = Detector.new frag
      matches = [] of MatchData
      matches.concat detector.matches
      detector.unmatched_atoms.each_fragment do |frag|
        matches << make_match(frag)
      end
      fragments << matches
    end

    polymers, other = fragments.partition &.size.>(1)
    other = other.flatten.sort_by!(&.reskind).group_by(&.reskind).values
    polymers.size + other.size <= MAX_CHAINS ? polymers + other : [fragments.flatten]
  end

  private def make_match(atoms : Enumerable(Atom)) : MatchData
    atom_map = Hash(String, Atom).new initial_capacity: atoms.size
    ele_index = Hash(Element, Int32).new default_value: 0
    atoms.each do |atom|
      name = "#{atom.element.symbol}#{ele_index[atom.element] += 1}"
      atom_map[name] = atom
    end
    MatchData.new("UNK", :other, atom_map)
  end
end
