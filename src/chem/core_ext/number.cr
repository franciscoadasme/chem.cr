abstract struct Number
  RADIAN_TO_DEGREE = 180 / Math::PI
  DEGREE_TO_RADIAN = Math::PI / 180

  def *(other : Chem::Spatial::Vector) : Chem::Spatial::Vector
    other * self
  end

  def degree
    degrees
  end

  def degrees
    self * RADIAN_TO_DEGREE
  end

  def radian
    radians
  end

  def radians
    self * DEGREE_TO_RADIAN
  end

  def within?(range : Range(Number, Number)) : Bool
    range.includes? self
  end
end
