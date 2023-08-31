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

  # Returns the unit vector pointing towards this direction.
  #
  # ```
  # Direction::X.to_vector  # => Vec3[ 1  0  0 ]
  # Direction::Y.to_vector  # => Vec3[ 0  1  0 ]
  # Direction::XY.to_vector # => Vec3[ 0.7071068  0.7071068  0 ]
  # ```
  def to_vector : Vec3
    Vec3.new self
  end
end
