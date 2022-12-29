struct Chem::Templates::MatchData
  getter template : Residue

  def initialize(
    @template : Residue,
    @atom_map : Hash(Atom, ::Chem::Atom)
  )
  end

  def atom_map : Hash::View(Atom, ::Chem::Atom)
    @atom_map.view
  end
end
