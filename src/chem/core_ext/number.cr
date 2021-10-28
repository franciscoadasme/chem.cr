abstract struct Number
  RADIAN_TO_DEGREE = 180 / Math::PI
  DEGREE_TO_RADIAN = Math::PI / 180

  def *(other : Chem::Spatial::Vec3) : Chem::Spatial::Vec3
    other * self
  end

  # Returns `true` if numbers are within *delta* from each other, else
  # `false`.
  #
  # ```
  # 1.0.close_to?(1.0)                          # => true
  # 1.0_f32.close_to?(1.0)                      # => true
  # 1.0.close_to?(1.0 + Float64::EPSILON)       # => true
  # 1.0_f32.close_to?(1.0 + Float32::EPSILON)   # => true
  # 1.0.close_to?(1.0005, 1e-3)                 # => true
  # 1.0.close_to?(1.0 + Float64::EPSILON*2)     # => false
  # 1.0_f32.close_to?(1.0 + Float32::EPSILON*2) # => false
  # 1.0.close_to?(1.01, 1e-3)                   # => false
  # ```
  def close_to?(rhs : Number, delta : Number = 0) : Bool
    (self - rhs).abs <= delta
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

  # Scales the number into the given range. The result will be between
  # zero and one.
  #
  # ```
  # 10.scale(0, 100)   # => 0.1
  # 2.5.scale(0, 5)    # 0.5
  # 401.scale(50, 500) # => 0.78
  # ```
  def scale(min : Number, max : Number) : Float64
    (self - min) / (max - min)
  end

  # :ditto:
  def scale(range : Range(Number, Number)) : Float64
    scale range.begin, range.end
  end

  # Reverts the scaling in the given range.
  #
  # 0.5.unscale(0, 100) # => 50.0
  # 0.1.unscale(0, 5) # => 0.05
  # 5.scale(-4, 20).unscale(-4, 20) # => 5.0
  def unscale(min : Number, max : Number) : Float64
    self * (max - min) + min
  end

  # :ditto:
  def unscale(range : Range(Number, Number)) : Float64
    unscale range.begin, range.end
  end
end
