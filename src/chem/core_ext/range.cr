struct Range(B, E)
  # Case equality. Delegates to `Chem::Atom#matches?`.
  def ===(atom : Chem::Atom) : Bool
    atom.matches?(self)
  end

  # Case equality. Delegates to `Chem::Chain#matches?`.
  def ===(chain : Chem::Chain) : Bool
    chain.matches?(self)
  end

  # Case equality. Delegates to `Chem::Residue#matches?`.
  def ===(residue : Chem::Residue) : Bool
    residue.matches?(self)
  end

  def clamp(min, max) : Range
    raise ArgumentError.new "Can't clamp an exclusive range" if exclusive?
    if (b = @begin) && (e = @end)
      b.clamp(min, max)..e.clamp(min, max)
    elsif b = @begin
      b.clamp(min, max)..max
    elsif e = @end
      min..e.clamp(min, max)
    else
      min..max
    end
  end

  def clamp(range : Range) : Range
    if range.end.nil? || !range.exclusive?
      clamp range.begin, range.end
    else
      raise ArgumentError.new "Can't clamp by an exclusive range"
    end
  end
end
