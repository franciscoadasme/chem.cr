module Chem
  abstract struct Bias; end

  enum Constraint
    X
    Y
    Z
    XY
    XZ
    YZ
    XYZ

    def includes?(axis : Constraint) : Bool
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
end
