class Chem::Topology::Detector
  @atom_top_specs : Hash(Atom, String)
  @atoms_with_spec : Hash(String, Array(Atom))

  def initialize(atoms : Enumerable(Atom))
    @atom_top_specs = atoms.to_h do |atom|
      top_spec = String.build do |io|
        io << atom.element.symbol
        # The order must be the same as the `AtomTemplate#top_spec`!
        atom.bonded_atoms.sort_by(&.atomic_number.-)
          .join(io) { |atom| io << atom.element.symbol }
      end
      {atom, top_spec}
    end
    @unmatched_atoms = atoms.to_set
    @atoms_with_spec = atoms.to_a.group_by { |atom| @atom_top_specs[atom] }
  end

  def detect(
    templates : TemplateRegistry = TemplateRegistry.default
  ) : {Array(MatchData), AtomView}
    matches = [] of MatchData
    templates.to_a.sort_by(&.atoms.size.-).each do |res_t| # largest to smallest
      next unless (res_t.atoms.size <= @unmatched_atoms.size) &&
                  (root_atoms = @atoms_with_spec[res_t.root.top_spec]?)
      ters = templates.ters.select &.type.==(res_t.type)
      i = 0
      while i < root_atoms.size
        root_atom = root_atoms.unsafe_fetch(i)
        next unless root_atom.in?(@unmatched_atoms)

        atom_map = {} of AtomTemplate => Atom
        search res_t, res_t.root, root_atom, atom_map
        extend_search atom_map, ters unless ters.empty?
        if atom_map.size >= res_t.atoms.size # may contain Ter atoms
          matches << MatchData.new(res_t, sort_match(atom_map, res_t.atoms))
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

  private def extend_search(
    atom_map : Hash(AtomTemplate, Atom),
    ters : Enumerable(TerTemplate)
  ) : Nil
    visited = atom_map.values.to_set
    unmatched_neighbors = visited.flat_map(&.bonded_atoms).reject!(&.in?(visited))
    ter_map = {} of AtomTemplate => Atom
    ters.each do |ter_t|
      unmatched_neighbors.each do |atom|
        next unless @atom_top_specs[atom] == ter_t.root.top_spec
        search ter_t, ter_t.root, atom, ter_map, visited.dup
        if ter_map.size == ter_t.atoms.size
          atom_map.merge! ter_map
          return
        end
        ter_map.clear
      end
    end
  end

  # Use *visited* to ensure that it's matched once as multiple atoms may
  # match the same template
  private def search(res_t : ResidueTemplate | TerTemplate,
                     atom_t : AtomTemplate,
                     atom : Atom,
                     atom_map : Hash(AtomTemplate, Atom),
                     visited : Set(Atom) = Set(Atom).new) : Nil
    return unless atom.in?(@unmatched_atoms) &&
                  !atom_map.has_key?(atom_t) &&
                  !atom.in?(visited) &&
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

# Returns a new atom map that preserves the order of the atom templates.
# If Ter (extra) atoms are found, they are placed after the ter's root.
private def sort_match(
  atom_map : Hash(Chem::AtomTemplate, Chem::Atom),
  sorted_atoms : Indexable(Chem::AtomTemplate)
) : Hash(Chem::AtomTemplate, Chem::Atom)
  atoms = atom_map.keys
    .sort_by! { |atom_t| sorted_atoms.index(atom_t) || Int32::MAX }

  # Place Ter atoms at the ter's root original position
  if atoms.size > sorted_atoms.size
    ter_i = atoms.index!(sorted_atoms.last)
    atoms, ter_atoms = atoms[..ter_i], atoms[(ter_i + 1)..]

    ter_i = sorted_atoms.index! &.name.==(ter_atoms[0].name)
    atoms = atoms[...ter_i] + ter_atoms + atoms[ter_i..]
  end

  atoms.to_h { |atom_t| {atom_t, atom_map[atom_t]} }
end
