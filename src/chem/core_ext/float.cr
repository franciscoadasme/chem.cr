struct Float
  # Returns `true` if numbers are within *delta* from each other, else `false`.
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
  def close_to?(other : Number, delta : Number = {{@type.constant("EPSILON")}}) : Bool
    (self - other).abs <= delta
  end
end
