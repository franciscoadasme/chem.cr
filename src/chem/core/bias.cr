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

    def includes?(axis : Symbol) : Bool
      case axis
      when :x
        xyz? || x? || xy? || xz?
      when :y
        xyz? || y? || xy? || yz?
      when :z
        xyz? || z? || xz? || yz?
      else
        false
      end
    end
  end
end
