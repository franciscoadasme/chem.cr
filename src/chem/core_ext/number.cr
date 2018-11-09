require "../spatial/vector"

abstract struct Number
  RADIAN_TO_DEGREE = 180 / Math::PI
  DEGREE_TO_RADIAN = Math::PI / 180

  def *(other : Chem::Spatial::Vector) : Chem::Spatial::Vector
    other * self
  end

  def degree : self
    degrees
  end

  def degrees : self
    self * RADIAN_TO_DEGREE
  end

  def radian : self
    radians
  end

  def radians : self
    self * DEGREE_TO_RADIAN
  end

  def within?(range : Range(Number, Number)) : Bool
    range.includes? self
  end
end
