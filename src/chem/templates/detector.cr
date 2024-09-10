# TODO: Change signature to Detector.new(registry).detect atoms
class Chem::Templates::Detector
  @atom_top_specs : Hash(::Chem::Atom, String)
  @atoms_with_spec : Hash(String, Array(::Chem::Atom))

  def initialize(atoms : Enumerable(::Chem::Atom))
    @atom_top_specs = atoms.to_h do |atom|
      top_spec = String.build do |io|
        io << atom.element.symbol
        # The order must be the same as the `Atom#top_spec`!
        atom.bonded_atoms.sort_by(&.atomic_number.-)
          .join(io) { |atom| io << atom.element.symbol }
      end
      {atom, top_spec}
    end
    @unmatched_atoms = atoms.to_set
    @atoms_with_spec = atoms.to_a.group_by { |atom| @atom_top_specs[atom] }
  end

  def detect(templates : Registry = Registry.default) : {Array(MatchData), AtomView}
    matches = [] of MatchData
    templates.to_a.sort_by(&.atoms.size.-).each do |res_t| # largest to smallest
      next unless (res_t.atoms.size <= @unmatched_atoms.size) &&
                  (root_atoms = @atoms_with_spec[res_t.root.top_spec]?)
      ters = templates.ters.select &.type.==(res_t.type)
      i = 0
      while i < root_atoms.size
        root_atom = root_atoms.unsafe_fetch(i)
        next unless root_atom.in?(@unmatched_atoms)

        atom_map = {} of Atom => ::Chem::Atom
        search res_t, res_t.root, root_atom, atom_map
        ter_map = extend_search(res_t, atom_map, ters) unless ters.empty?
        if atom_map.size + (ter_map.try(&.size) || 0) >= res_t.atoms.size
          atom_map = sort_match(res_t, atom_map)
          atom_map = merge_ter(res_t, atom_map, ter_map) if ter_map
          matches << MatchData.new(res_t, atom_map)
          atom_map.each_value do |atom|
            @unmatched_atoms.delete atom
            @atoms_with_spec[@atom_top_specs[atom]].delete atom
          end
          i -= 1 # decrease index because current atom was removed
        end
        i += 1
      end
    end
    {matches, AtomView.new(@unmatched_atoms.to_a.sort_by!(&.serial))}
  end

  # Extends a residue template match by adding atoms based on Ter
  # templates.
  #
  # It detects root candidates in two ways:
  #
  # 1. Checks for an atom with the same name as the Ter's root in the
  # given match, and if exists, starts the search from it. The matched
  # atoms having names equal to the Ter's atoms are rematched. This
  # allows for a Ter to overwrite residue atoms with the same
  # name/topology.
  # 2. Atoms bonded to the Ter's root in the residue template are looked
  # for in the given match to get their bonded atoms. Atoms already
  # visited/matched are ignored.
  #
  # The candidate root atoms are tested by calling the `#search` method.
  private def extend_search(
    res_t : Residue,
    atom_map : Hash(Atom, ::Chem::Atom),
    ters : Enumerable(Ter)
  ) : Hash(Atom, ::Chem::Atom)?
    visited = atom_map.values.to_set
    ter_map = {} of Atom => ::Chem::Atom
    ters.each do |ter_t|
      if root_match = atom_map.find(&.[0].name.==(ter_t.root.name))
        # if the template match has an atom named as the root, then
        # start the search at the matched atom
        ter_names = ter_t.atoms.map(&.name)
        ter_visited = visited.dup
        atom_map.each do |atom_t, atom|
          ter_visited.delete atom if atom_t.name.in? ter_names
        end
        search ter_t, ter_t.root, root_match[1], ter_map.clear, ter_visited
        return ter_map if ter_map.size == ter_t.atoms.size
      else # search all root candidates
        res_t.bonds
          .compact_map(&.other?(ter_t.root.name))     # atoms (by name) bonded to ter root
          .select(&.element.heavy?)                   # ignore hydrogens
          .compact_map { |atom_t| atom_map[atom_t]? } # get matched atoms
          .flat_map(&.bonded_atoms)                   # get possible root atoms
          .reject!(&.in?(visited))                    # skip already matched/visited
          .each do |root_atom|
            next unless @atom_top_specs[root_atom] == ter_t.root.top_spec
            search ter_t, ter_t.root, root_atom, ter_map.clear, visited.dup
            return ter_map if ter_map.size == ter_t.atoms.size
          end
      end
    end
  end

  # Use *visited* to ensure that it's matched once as multiple atoms may
  # match the same template
  private def search(res_t : Residue | Ter,
                     atom_t : Atom,
                     atom : ::Chem::Atom,
                     atom_map : Hash(Atom, ::Chem::Atom),
                     visited : Set(::Chem::Atom) = Set(::Chem::Atom).new) : Nil
    return unless atom.in?(@unmatched_atoms) &&
                  !atom_map.has_key?(atom_t) &&
                  !atom.in?(visited) &&
                  atom.formal_charge == atom_t.formal_charge &&
                  @atom_top_specs[atom] == atom_t.top_spec
    atom_map[atom_t] = atom
    visited << atom
    res_t.bonds.compact_map(&.other?(atom_t)).each do |other_t|
      atom.each_bonded_atom do |other|
        search res_t, other_t, other, atom_map, visited
      end
    end
  end
end

# Returns a new residue template match that preserves the atom order.
private def sort_match(
  res_t : Chem::Templates::Residue,
  atom_map : Hash(Chem::Templates::Atom, Chem::Atom),
) : Hash(Chem::Templates::Atom, Chem::Atom)
  atom_map.to_a
    .sort_by! do |atom_t, _|
      res_t.atoms.index(&.name.==(atom_t.name)) ||
        raise Chem::Error.new("Could not find atom #{atom_t.name} in \
                             residue template #{res_t.name}")
    end
    .to_h
end

# Returns a new residue template match by merging the ter match into the
# given match. The ter's atoms are placed after the ter's root if
# present, else at the end of the match.
private def merge_ter(
  res_t : Chem::Templates::Residue,
  atom_map : Hash(Chem::Templates::Atom, Chem::Atom),
  ter_map : Hash(Chem::Templates::Atom, Chem::Atom)
) : Hash(Chem::Templates::Atom, Chem::Atom)
  sorted_matches = atom_map.to_a
  ter_matches = ter_map.to_a
  if index = res_t.atoms.index(&.name.==(ter_map.first_key.name))
    if index > 0
      prev_name = res_t.atoms[index - 1].name
      index = sorted_matches.index(&.[0].name.==(prev_name)) ||
              raise Chem::Error.new(
                "Could not find preceding atom #{prev_name} to ter \
                 root in atom matches")
      while sorted_matches[index + 1]?.try(&.[0].element.hydrogen?)
        index += 1
      end
      sorted_matches.insert_all index + 1, ter_matches
    else
      sorted_matches = ter_matches + sorted_matches
    end
  else
    sorted_matches.concat ter_matches
  end
  sorted_matches.to_h
end
