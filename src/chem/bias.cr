module Chem
  abstract struct Bias; end

  struct Constraint < Bias
    enum Direction
      None
      X
      Y
      Z
      XY
      XZ
      YZ
      XYZ
    end

    getter direction : Direction

    def initialize(@direction : Direction = :xyz)
    end

    def includes?(axis : Symbol) : Bool
      case axis
      when :x
        direction.xyz? || direction.x? || direction.xy? || direction.xz?
      when :y
        direction.xyz? || direction.y? || direction.xy? || direction.yz?
      when :z
        direction.xyz? || direction.z? || direction.xz? || direction.yz?
      else
        false
      end
    end
  end
end
