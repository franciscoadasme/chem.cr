# An enum that represents directions along the axes in 3D space.
enum Chem::Spatial::Direction
  # Direction along the X axis
  X
  # Direction along the Y axis
  Y
  # Direction along the Z axis
  Z
  # Direction along the X and Y axes
  XY
  # Direction along the X and Z axes
  XZ
  # Direction along the Y and Z axes
  YZ
  # Direction along the X, Y, and Z axes
  XYZ

  # Returns `true` if the direction includes the component *axis*, else
  # `false`.
  #
  # ```
  # Direction::X.includes?(:x)    # => true
  # Direction::Y.includes?(:x)    # => false
  # Direction::XY.includes?(:x)   # => true
  # Direction::YZ.includes?(:x)   # => false
  # Direction::XYZ.includes?(:x)  # => true
  # Direction::XY.includes?(:xy)  # => true
  # Direction::X.includes?(:xy)   # => false
  # Direction::XY.includes?(:xy)  # => true
  # Direction::XZ.includes?(:xy)  # => false
  # Direction::XYZ.includes?(:xy) # => true
  # ```
  def includes?(axis : self) : Bool
    case axis
    in .x?   then x? || xy? || xz? || xyz?
    in .y?   then y? || xy? || yz? || xyz?
    in .z?   then z? || xz? || yz? || xyz?
    in .xy?  then xy? || xyz?
    in .xz?  then xz? || xyz?
    in .yz?  then yz? || xyz?
    in .xyz? then xyz?
    end
  end
end
