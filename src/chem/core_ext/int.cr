abstract struct Int
  # Case equality. Delegates to `Chem::Atom#matches?`.
  def ===(atom : Chem::Atom) : Bool
    atom.matches?(self)
  end

  # Case equality. Delegates to `Chem::Residue#matches?`.
  def ===(residue : Chem::Residue) : Bool
    residue.matches?(self)
  end
end
