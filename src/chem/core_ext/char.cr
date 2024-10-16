struct Char
  # Case equality. Delegates to `Chem::Chain#matches?`.
  def ===(chain : Chem::Chain) : Bool
    chain.matches?(self)
  end

  # Case equality. Delegates to `Chem::Residue#matches?`.
  def ===(residue : Chem::Residue) : Bool
    residue.matches?(self)
  end

  def presence
    self unless ascii_whitespace?
  end
end
