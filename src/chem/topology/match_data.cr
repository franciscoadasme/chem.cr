struct Chem::Topology::MatchData
  getter template : ResidueTemplate

  def initialize(
    @template : ResidueTemplate,
    @atom_map : Hash(AtomTemplate, Atom)
  )
  end

  def atom_map : Hash::View(AtomTemplate, Atom)
    @atom_map.view
  end
end
