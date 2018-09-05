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
  end
end
