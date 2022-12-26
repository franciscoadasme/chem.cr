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
      i = 0
      while i < root_atoms.size
        root_atom = root_atoms.unsafe_fetch(i)
        next unless root_atom.in?(@unmatched_atoms)

        matched_atoms = search res_t, root_atom
        if matched_atoms.size >= res_t.atoms.size # may contain Ter atoms
          matches << MatchData.new(res_t, matched_atoms.invert)
          matched_atoms.each_key do |atom|
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

  private def extend_match(res_t : ResidueTemplate,
                           root_atom : Atom,
                           atom_map : Hash(Atom, String))
    ter_map = {} of Atom => String
    self.class.protein_ters.each do |ter_t|
      root_atom.each_bonded_atom do |other|
        search ter_t, ter_t.root, other, ter_map
      end

      if ter_map.size == ter_t.atoms.size - 4 # ter has an extra CH3
        atom_map.merge! ter_map
        break
      end
      ter_map.clear
    end
  end

  # TODO: refactor into Templates::Ter in TemplateRegistry
  protected def self.protein_ters : Array(ResidueTemplate)
    @@protein_ters ||= [
      ResidueTemplate.build(&.name("CTER").spec("CA-C(=O)-OXT").root("C")),
      ResidueTemplate.build(&.name("CTER").spec("CA-C(=O)-[OXT-]").root("C")),
      ResidueTemplate.build(&.name("NTER").spec("CA-N").root("N")),
      ResidueTemplate.build(&.name("NTER").spec("CA-[NH3+]").root("N")),
    ]
  end

  private def search(res_t : ResidueTemplate, root_atom : Atom) : Hash(Atom, String)
    atom_map = {} of Atom => String
    search res_t, res_t.root, root_atom, atom_map
    if res_t.type.protein? && (root_atom = atom_map.key_for?("CA"))
      extend_match res_t, root_atom, atom_map
    end
    atom_map
  end

  # Use *matched_templates* to ensure that it's matched once as multiple
  # atoms may match the template
  private def search(res_t : ResidueTemplate,
                     atom_t : AtomTemplate,
                     atom : Atom,
                     atom_map : Hash(Atom, String),
                     matched_templates : Set(AtomTemplate) = Set(AtomTemplate).new) : Nil
    return unless atom.in?(@unmatched_atoms) &&
                  !atom_map.has_key?(atom) &&
                  !atom_t.in?(matched_templates) &&
                  @atom_top_specs[atom] == atom_t.top_spec
    atom_map[atom] = atom_t.name
    matched_templates << atom_t
    res_t.bonds.compact_map(&.other?(atom_t)).each do |other_t|
      atom.each_bonded_atom do |other|
        search res_t, other_t, other, atom_map, matched_templates
      end
    end
  end
end
